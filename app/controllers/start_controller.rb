# frozen_string_literal: true

# this is temp, it'll be refactored

class StartController < ApplicationController
  STEPS = %w[name project devlog signin].freeze

  def index
    authorize :start, :index?

    @step = normalize_step(params[:step])
    @display_name = session[:start_display_name]
    @project_attrs = session[:start_project_attrs] || {}
    @devlog_body = session[:start_devlog_body]
    @devlog_attachment_ids = session[:start_devlog_attachment_ids] || []
  end

  def update_display_name
    session[:start_display_name] = start_display_name_param
    redirect_to start_path(step: "project")
  end

  def update_project
    session[:start_project_attrs] = start_project_params.to_h
    redirect_to start_path(step: "devlog")
  end

  def update_devlog
    session[:start_devlog_body] = start_devlog_body_param

    # store the blobies (direct upload)
    attachment_ids = Array(params[:devlog_attachment_ids]).reject(&:blank?)
    session[:start_devlog_attachment_ids] = attachment_ids

    redirect_to start_path(step: "signin")
  end

  private

  # this is temp, it'll be refactored
  def normalize_step(step)
    STEPS.include?(step) ? step : "name"
  end

  def start_display_name_param
    params.require(:display_name).to_s.strip[0, 80]
  rescue ActionController::ParameterMissing
    ""
  end

  def start_project_params
    params.require(:project).permit(:title, :description)
  rescue ActionController::ParameterMissing
    {}
  end

  def start_devlog_body_param
    params.require(:devlog_body).to_s[0, 10_000]
  rescue ActionController::ParameterMissing
    ""
  end
end
