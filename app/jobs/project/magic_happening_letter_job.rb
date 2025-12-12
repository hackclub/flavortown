class Project::MagicHappeningLetterJob < ApplicationJob
  queue_as :default

  def perform(project)
    owner = project.memberships.owner.first&.user
    return unless owner&.frozen_address

    response = TheseusService.create_letter_v1(
      "instant/flavortown-magic-happening",
      {
        recipient_email: owner.email,
        address: owner.frozen_address,
        idempotency_key: "flavortown_magic_project_#{project.id}",
        metadata: {
          flavortown_user: owner.id,
          project: project.title,
          reviewer: project.marked_fire_by&.display_name
        }
      }
    )

    project.update!(fire_letter_id: response[:id])
  end
end
