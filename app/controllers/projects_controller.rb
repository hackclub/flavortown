class ProjectsController < ApplicationController
  before_action :set_project_minimal, only: [ :edit, :update, :destroy ]
  before_action :set_project, only: [ :show ]

  def index
    authorize Project
    @projects = current_user.projects
      .includes(banner_attachment: :blob)
      .left_joins(:devlogs)
      .select("projects.*, COUNT(posts.id) AS devlogs_count")
      .group("projects.id")
  end

  def show
    authorize @project
    @posts = @project
      .posts
      .order(created_at: :desc)
      .includes(:user, postable: [ { attachments_attachments: :blob } ])
  end

  def new
    @project = Project.new
    authorize @project
    load_project_times
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    validate_hackatime_projects
    validate_urls

    if @project.errors.empty? && @project.save
      # Create membership for the current user as owner
      @project.memberships.create!(user: current_user, role: :owner)
      link_hackatime_projects
      flash[:notice] = "Project created successfully"
      current_user.complete_tutorial_step! :create_project
      redirect_to @project
    else
      flash[:alert] = "Failed to create project: #{@project.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @project
    load_project_times
  end

  def update
    authorize @project

    @project.assign_attributes(project_params)
    validate_urls

    if @project.errors.empty? && @project.save
      flash[:notice] = "Project updated successfully"
      redirect_to @project
    else
      flash[:alert] = "Failed to update project: #{@project.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    @project.destroy
    current_user.revoke_tutorial_step! :create_project if current_user.projects.empty?
    flash[:notice] = "Project deleted successfully"
    redirect_to projects_path
  end

  private

  # These are the same today, but they'll be different tomorrow.

  def set_project
    @project = Project.find(params[:id])
  end

  def set_project_minimal
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :description, :demo_url, :repo_url, :readme_url, :banner)
  end

  def hackatime_project_ids
    @hackatime_project_ids ||= Array(params[:project][:hackatime_project_ids]).reject(&:blank?)
  end

  def validate_hackatime_projects
    return if hackatime_project_ids.empty?

    already_linked = current_user.hackatime_projects
                                 .where(id: hackatime_project_ids)
                                 .where.not(project_id: nil)

    return unless already_linked.any?

    @project.errors.add(:base, "The following Hackatime projects are already linked: #{already_linked.pluck(:name).join(', ')}")
  end

  def validate_urls
    if @project.demo_url.blank? && @project.repo_url.blank? && @project.readme_url.blank?
      return
    end


    if @project.demo_url.present? && @project.repo_url.present?
      if @project.demo_url == @project.repo_url || @project.demo_url == @project.readme_url
        @project.errors.add(:base, "Demo URL and Repository URL cannot be the same")
      end
    end

    validate_url_not_dead(:demo_url, "Demo URL") if @project.demo_url.present? && @project.errors.empty?

    validate_url_not_dead(:repo_url, "Repository URL") if @project.repo_url.present? && @project.errors.empty?
    validate_url_not_dead(:readme_url, "Readme URL") if @project.readme_url.present? && @project.errors.empty?
  end

  def validate_url_not_dead(attribute, name)
    require "uri"
    require "faraday"

    return unless @project.send(attribute).present?

    uri = URI.parse(@project.send(attribute))
    conn = Faraday.new(
      url: uri.to_s,
      headers: { "User-Agent" => "Flavortown project validtor (https://flavortown.hackclub.com/)" }
    )
    response = conn.get() do |req|
      req.options.timeout = 5
      req.options.open_timeout = 5
    end

    unless response.status == 200
      @project.errors.add(attribute, "Your #{name} needs to return a 200 status. I got #{response.status}, is your code/website set to public!?!?")
    end


    # Copy pasted from https://github.com/hackclub/summer-of-making/blob/29e572dd6df70627d37f3718a6ebd4bafb07f4c7/app/controllers/projects_controller.rb#L275
    if attribute != :demo_url
      repo_patterns = [
        %r{/blob/}, %r{/tree/}, %r{/src/}, %r{/raw/}, %r{/commits/},
        %r{/pull/}, %r{/issues/}, %r{/compare/}, %r{/releases/},
        /\.git$/, %r{/commit/}, %r{/branch/}, %r{/blame/},

        %r{/projects/}, %r{/repositories/}, %r{/gitea/}, %r{/cgit/},
        %r{/gitweb/}, %r{/gogs/}, %r{/git/}, %r{/scm/},

        /\.(md|py|js|ts|jsx|tsx|html|css|scss|php|rb|go|rs|java|cpp|c|h|cs|swift)$/
      ]

      # Known code hosting platforms (not required, but used for heuristic)
      known_platforms = [
        "github", "gitlab", "bitbucket", "dev.azure", "sourceforge",
        "codeberg", "sr.ht", "replit", "vercel", "netlify", "glitch",
        "hackclub", "gitea", "git", "repo", "code"
      ]

      path = uri.path.downcase
      host = uri.host.downcase

      is_valid_repo_url = false

      if repo_patterns.any? { |pattern| path.match?(pattern) }
        is_valid_repo_url = true
      elsif attribute == :readme_url && (host.include?("raw.githubusercontent") || path.include?("/readme") || path.end_with?(".md") || path.end_with?("readme.txt"))
        is_valid_repo_url = true
      elsif known_platforms.any? { |platform| host.include?(platform) }
        is_valid_repo_url = path.split("/").size > 2
      elsif path.split("/").size > 1 && path.exclude?("wp-") && path.exclude?("blog")
        is_valid_repo_url = true
      end

      unless is_valid_repo_url
        @project.errors.add(attribute, "#{name} does not appear to be a valid repository or project URL")
      end
    end

  rescue URI::InvalidURIError
    @project.errors.add(attribute, "#{name} is not a valid URL")
  rescue Faraday::ConnectionFailed => e
    @project.errors.add(attribute, "Please make sure the url is valid and reachable: #{e.message}")
  rescue StandardError => e
    @project.errors.add(attribute, "#{name} could not be verified (idk why, pls let a admin know if this is happning alot and your sure that the url is valid): #{e.message}")
  end

  def link_hackatime_projects
    return if hackatime_project_ids.empty?

    current_user.hackatime_projects.where(id: hackatime_project_ids).find_each do |hp|
      hp.update!(project: @project)
    end
  end

  def load_project_times
    hackatime_identity = current_user.identities.find_by(provider: "hackatime")
    @project_times = if hackatime_identity
                       HackatimeService.fetch_user_projects_with_time(hackatime_identity.uid)
    else
                       {}
    end
  end
end
