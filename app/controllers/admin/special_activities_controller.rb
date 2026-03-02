module Admin
  class SpecialActivitiesController < Admin::ApplicationController
    PRESENTATION_PAYOUT_AMOUNT = ShowAndTellAttendance::PRESENTATION_PAYOUT_AMOUNT
    WINNER_PAYOUT_AMOUNT = ShowAndTellAttendance::WINNER_PAYOUT_AMOUNT

    def index
      authorize :admin, :access_special_activities?
      @date = params[:date]
      @attendances = if @date.present?
        ShowAndTellAttendance.includes(:user, :project).where(date: @date).order(:id)
      else
        ShowAndTellAttendance.includes(:user, :project).order(date: :desc, id: :asc)
      end
      @dates = ShowAndTellAttendance.distinct.order(date: :desc).pluck(:date)
      @payout_record = @date.present? ? ShowAndTellPayoutRecord.find_by(date: @date) : nil
    end

    def create
      authorize :admin, :access_special_activities?

      if params[:csv_file].blank? || params[:date].blank?
        flash[:alert] = "Please select a file and a date."
        return redirect_to admin_special_activities_path
      end

      csv = params[:csv_file].read
      parsed = CSV.parse(csv, headers: true)
      date = params[:date]

      parsed.each do |row|
        slack_id = row["Slack Member ID"]&.strip
        next if slack_id.blank?

        user = User.find_by(slack_id: slack_id)
        next unless user

        project = extract_project_from_url(row["Project URL"])

        attendance = ShowAndTellAttendance.find_or_initialize_by(user: user, date: date)
        attendance.project = project if project
        attendance.give_presentation_payout = project.present? && !attendance.monthly_payout_limit_reached?
        attendance.save!
      end

      redirect_to admin_special_activities_path(date: date), notice: "Attendance imported!"
    end

    def toggle_payout
      authorize :admin, :access_special_activities?

      attendance = ShowAndTellAttendance.find(params[:id])
      payout_record = ShowAndTellPayoutRecord.find_by(date: attendance.date)

      if payout_record
        return redirect_to admin_special_activities_path(date: attendance.date), alert: "Payout already finalized for this date."
      end

      PaperTrail.request(whodunnit: current_user.id) do
        attendance.update!(give_presentation_payout: !attendance.give_presentation_payout)
      end

      redirect_to admin_special_activities_path(date: attendance.date)
    end

    def give_payout
      authorize :admin, :access_special_activities?

      date = params[:date]
      if date.blank?
        return redirect_to admin_special_activities_path, alert: "No date specified."
      end

      payout_record = ShowAndTellPayoutRecord.find_by(date: date)
      if payout_record
        return redirect_to admin_special_activities_path(date: date), alert: "Payout already given for this Show & Tell."
      end

      attendances = ShowAndTellAttendance.where(date: date, give_presentation_payout: true, payout_given: false)
        .includes(:user)

      if attendances.empty?
        return redirect_to admin_special_activities_path(date: date), alert: "No eligible attendees for payout."
      end

      ActiveRecord::Base.transaction do
        PaperTrail.request(whodunnit: current_user.id) do
          attendances.each do |attendance|
            attendance.ledger_entries.create!(
              user: attendance.user,
              amount: PRESENTATION_PAYOUT_AMOUNT,
              reason: "Show and Tell #{date} Payout",
              created_by: "show_and_tell_payout"
            )
            attendance.update!(payout_given: true, payout_given_at: Time.current, payout_given_by: current_user)
            attendance.user.invalidate_balance_cache!
          end

          ShowAndTellPayoutRecord.create!(date: date, payout_given_by: current_user, notes: "Payout distributed to #{attendances.size} attendees")
        end
      end

      redirect_to admin_special_activities_path(date: date), notice: "Payout of #{PRESENTATION_PAYOUT_AMOUNT} cookies given to #{attendances.size} attendees."
    end

    def mark_payout_given
      authorize :admin, :access_special_activities?

      date = params[:date]
      if date.blank?
        return redirect_to admin_special_activities_path, alert: "No date specified."
      end

      if ShowAndTellPayoutRecord.exists?(date: date)
        return redirect_to admin_special_activities_path(date: date), alert: "Payout already marked as given."
      end

      PaperTrail.request(whodunnit: current_user.id) do
        ShowAndTellPayoutRecord.create!(date: date, payout_given_by: current_user, notes: "Manually marked as paid (historical)")
      end

      redirect_to admin_special_activities_path(date: date), notice: "Payout marked as given for #{date}."
    end

    def mark_winner
      authorize :admin, :access_special_activities?

      attendance = ShowAndTellAttendance.find(params[:id])

      if attendance.winner?
        return redirect_to admin_special_activities_path(date: attendance.date), alert: "Already marked as winner."
      end

      unless attendance.presented_project?
        return redirect_to admin_special_activities_path(date: attendance.date), alert: "Only presenters can be marked as winners."
      end

      ActiveRecord::Base.transaction do
        PaperTrail.request(whodunnit: current_user.id) do
          attendance.ledger_entries.create!(
            user: attendance.user,
            amount: WINNER_PAYOUT_AMOUNT,
            reason: "Show and Tell #{attendance.date} Winner Payout",
            created_by: "show_and_tell_winner"
          )
          attendance.update!(winner: true, winner_payout_given: true)
          attendance.user.invalidate_balance_cache!
        end
      end

      redirect_to admin_special_activities_path(date: attendance.date), notice: "#{attendance.user.display_name} marked as winner and awarded #{WINNER_PAYOUT_AMOUNT} cookies!"
    end

    private

    def extract_project_from_url(url)
      return nil if url.blank?

      match = url.to_s.strip.match(%r{/projects/(\d+)})
      return nil unless match

      Project.find_by(id: match[1])
    end
  end
end
