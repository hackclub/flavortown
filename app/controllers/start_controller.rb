# frozen_string_literal: true

class StartController < ApplicationController
  STEPS = %w[name project devlog signin].freeze

  before_action :set_step, only: :index
  before_action :enforce_step_order, only: :index

  def index
    authorize :start, :index?

    @display_name = session[:start_display_name]
    @email = session[:start_email]
    @project_attrs = session[:start_project_attrs] || {}
    @devlog_body = session[:start_devlog_body]
    @devlog_attachment_ids = session[:start_devlog_attachment_ids] || []
  end

  def update_display_name
    display_name = params.fetch(:display_name, "").to_s.strip.first(50)
    email = params.fetch(:email, "").to_s.strip.downcase.first(255)

    unless valid_email?(email)
      redirect_to start_path(step: "name"), alert: "Please enter a valid email address."
      return
    end

    session[:start_display_name] = display_name
    session[:start_email] = email
    redirect_to start_path(step: "project")
  end

  def update_project
    permitted = params.fetch(:project, {}).permit(:title, :description)
    session[:start_project_attrs] = {
      title: permitted[:title].to_s.strip.first(120),
      description: permitted[:description].to_s.strip.first(1_000)
    }
    redirect_to start_path(step: "devlog")
  end

  def update_devlog
    body = params.fetch(:devlog_body, "").to_s.strip.first(2_000)
    attachment_ids = Array(params[:devlog_attachment_ids]).compact_blank

    if attachment_ids.empty?
      redirect_to start_path(step: "devlog"), alert: "Please upload at least one image or video."
      return
    end

    session[:start_devlog_body] = body
    session[:start_devlog_attachment_ids] = attachment_ids
    redirect_to start_path(step: "signin")
  end

  private

  def set_step
    @step = STEPS.include?(params[:step]) ? params[:step] : "name"
  end

  def enforce_step_order
    required = first_incomplete_step
    return if @step == required || step_accessible?(@step)

    redirect_to start_path(step: required), alert: "Please complete the previous steps first."
  end

  def step_accessible?(step)
    step_index = STEPS.index(step) || 0
    required_index = STEPS.index(first_incomplete_step) || 0
    step_index <= required_index
  end

  def first_incomplete_step
    return "name"    unless name_complete?
    return "project" unless project_complete?
    return "devlog"  unless devlog_complete?
    "signin"
  end

  def name_complete?
    session[:start_display_name].present? && session[:start_email].present?
  end

  def project_complete?
    session[:start_project_attrs].present? && session[:start_project_attrs].any?
  end

  def devlog_complete?
    session[:start_devlog_body].present? && session[:start_devlog_attachment_ids].present?
  end

  def valid_email?(email)
    email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
  end
end
