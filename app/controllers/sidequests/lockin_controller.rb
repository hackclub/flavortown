module Sidequests
  class LockinController < ApplicationController
    include LockinWeeksHelper

    skip_after_action :verify_authorized, raise: false

    def dash
      @sidequest = Sidequest.find_by!(slug: "lockin")

      unless current_user
        redirect_to sidequest_path(@sidequest), alert: "You need to be signed in to access the lockin dashboard." and return
      end

      @active_week = lockin_active_week
      bounds = lockin_current_week_bounds
      @week_start = bounds[:start]
      @week_end = bounds[:end]

      @projects = current_user.projects.not_deleted

      selected_project_id = params[:project_id]
      @selected_project = @projects.find_by(id: selected_project_id) || @projects.first

      @week_seconds = 0
      @accomplishments = []

      hackatime_uid = current_user.hackatime_identity&.uid

      if @selected_project.present?
        @accomplishments = @selected_project.posts
          .where(postable_type: "Post::Devlog")
          .where(created_at: @week_start..@week_end)
          .includes(:postable, :user)
          .order(created_at: :desc)
          .limit(5)
          .to_a

        hackatime_keys = @selected_project.hackatime_keys

        if hackatime_uid.present? && hackatime_keys.present?
          total_seconds = HackatimeService.fetch_total_seconds_for_projects(
            hackatime_uid,
            hackatime_keys,
            start_date: @week_start.iso8601,
            end_date: @week_end.iso8601
          )
          @week_seconds = total_seconds || 0
        end

        hours_done = @week_seconds / 3600.0
        hours_remaining = [ 10.0 - hours_done, 0 ].max
        now = Time.current
        days_left = [ (@week_end - now) / 1.day, 0.5 ].max
        @daily_pace_needed = (hours_remaining / days_left).round(1)
        @hours_done = hours_done
      end

      @past_weeks_data = build_past_weeks_data(hackatime_uid)

      render "sidequests/dash_lockin"
    end

    private

    def build_past_weeks_data(hackatime_uid)
      return [] unless @active_week > 1

      past_week_nums = (1..[ (@active_week - 1), 4 ].min)


      projects_with_keys = @projects.map { |proj|
        { project: proj, keys: proj.hackatime_keys }
      }

      past_week_nums.map do |past_week_num|
        past_week = lockin_weeks.find { |w| w[:num] == past_week_num }
        week_total_seconds = 0
        active_projects = []

        projects_with_keys.each do |entry|
          proj = entry[:project]
          proj_posts = proj.posts
            .where(postable_type: "Post::Devlog")
            .where(created_at: past_week[:start]..past_week[:end])

          proj_hackatime_seconds = 0
          if hackatime_uid.present? && entry[:keys].present?
            proj_hackatime_seconds = HackatimeService.fetch_total_seconds_for_projects(
              hackatime_uid,
              entry[:keys],
              start_date: past_week[:start].iso8601,
              end_date: past_week[:end].iso8601
            ) || 0
          end

          if proj_posts.any? || proj_hackatime_seconds > 0
            active_projects << { project: proj, posts_count: proj_posts.count, hours: proj_hackatime_seconds / 3600.0 }
            week_total_seconds += proj_hackatime_seconds
          end
        end

        {
          week_num: past_week_num,
          start_date: past_week[:start],
          end_date: past_week[:end],
          total_hours: week_total_seconds / 3600.0,
          active_projects: active_projects
        }
      end
    end
  end
end
