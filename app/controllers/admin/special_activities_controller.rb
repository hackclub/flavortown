module Admin
  class SpecialActivitiesController < Admin::ApplicationController
    def index
      authorize :admin, :access_special_activities?
      @date = params[:date]
      @attendances = if @date.present?
        ShowAndTellAttendance.includes(:user).where(date: @date).order(:id)
      else
        ShowAndTellAttendance.includes(:user).order(date: :desc, id: :asc)
      end
      @dates = ShowAndTellAttendance.distinct.order(date: :desc).pluck(:date)
    end

    def create
      authorize :admin, :access_special_activities?
      if params[:csv_file].present? && params[:date].present?
        csv = params[:csv_file].read
        parsed = CSV.parse(csv, headers: true)
        slack_ids = parsed.map { |row| row["Slack Member ID"] }.compact.uniq

        users = User.where(slack_id: slack_ids).index_by(&:slack_id)
        date = params[:date]

        slack_ids.each do |slack_id|
          user = users[slack_id]
          next unless user
          ShowAndTellAttendance.find_or_create_by!(user: user, date: date)
        end

        redirect_to admin_special_activities_path(date: date), notice: "Attendance imported!"
      else
        flash[:alert] = "Please select a file and a date."
        redirect_to admin_special_activities_path
      end
    end
  end
end
