class Project::PostToMagicJob < ApplicationJob
  queue_as :default

  CHANNEL_ID = "U07L45W79E1"

  include Rails.application.routes.url_helpers

  def perform(project)
    owner = project.memberships.owner.first&.user
    return unless owner

    SendSlackDmJob.perform_later(
      CHANNEL_ID,
      nil,
      blocks_path: "notifications/magic_happening",
      locals: {
        project_title: project.title,
        project_description: project.description.to_s,
        project_url: project_url(project, host: "https://flavortown.hackclub.com"),
        owner_name: owner.display_name
      }
    )
  end
end
