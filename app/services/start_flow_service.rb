class StartFlowService
  Result = Struct.new(:success?, :errors, keyword_init: true)

  def initialize(user:, session_data:)
    @user = user
    @session_data = session_data
    @errors = []
  end

  def call
    ActiveRecord::Base.transaction do
      apply_display_name!
      project = create_project!
      create_devlog!(project) if project

      raise ActiveRecord::Rollback if @errors.any?
    end

    Result.new(success?: @errors.empty?, errors: @errors)
  end

  private

  def apply_display_name!
    start_display_name = @session_data[:start_display_name].to_s.strip
    return if start_display_name.blank?
    return if @user.display_name.to_s.strip.present?

    @user.display_name = start_display_name
    return if @user.save

    @errors.concat(@user.errors.full_messages.map { |msg| "Display name: #{msg}" })
  end

  def create_project!
    project_attrs = @session_data[:start_project_attrs] || {}
    title = project_attrs["title"].to_s.strip
    return nil if title.blank?

    project = Project.new(
      title: title,
      description: project_attrs["description"]
    )

    unless project.save
      @errors.concat(project.errors.full_messages.map { |msg| "Project: #{msg}" })
      return nil
    end

    project.memberships.create!(user: @user, role: :owner)
    @user.complete_tutorial_step!(:create_project)
    project
  end

  def create_devlog!(project)
    devlog_body = @session_data[:start_devlog_body].to_s
    attachment_ids = @session_data[:start_devlog_attachment_ids] || []

    return if devlog_body.blank? && attachment_ids.empty?

    devlog = Post::Devlog.new(body: devlog_body)
    attach_blobs!(devlog, attachment_ids)

    unless devlog.save
      @errors.concat(devlog.errors.full_messages.map { |msg| "Devlog: #{msg}" })
      return
    end

    post = Post.new(project: project, user: @user, postable: devlog)
    unless post.save
      @errors.concat(post.errors.full_messages.map { |msg| "Devlog post: #{msg}" })
      return
    end

    @user.complete_tutorial_step!(:post_devlog)
  end

  def attach_blobs!(devlog, attachment_ids)
    attachment_ids.each do |signed_id|
      blob = ActiveStorage::Blob.find_signed(signed_id)
      devlog.attachments.attach(blob) if blob
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      @errors << "Invalid attachment - please re-upload your files"
    end
  end
end
