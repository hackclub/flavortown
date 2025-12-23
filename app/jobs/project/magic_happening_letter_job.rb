class Project::MagicHappeningLetterJob < ApplicationJob
  queue_as :default

  def perform(project)
    unless Rails.env.production?
      Rails.logger.info "we'd be sending a letter about #{project.to_global_id} (#{project.title}) if we were in prod" and return
    end
    owner = project.memberships.owner.first&.user
    return unless owner

    address = owner.addresses.first

    if owner.email.blank? || address.blank?
      Rails.logger.warn(
        "MagicHappeningLetterJob: project #{project.id} missing owner email or address — re-enqueuing"
      )
      Project::MagicHappeningLetterJob.perform_later(project)
      return
    end

    response = TheseusService.create_letter_v1(
      "instant/flavortown-magic-happening",
      {
        recipient_email: owner.email,
        address: address,
        idempotency_key: "flavortown_magic_project_#{project.id}",
        metadata: {
          flavortown_user: owner.id,
          project: project.title,
          reviewer: project.marked_fire_by&.display_name
        }
      }
    )

    if response && response[:id]
      project.update!(fire_letter_id: response[:id])
    else
      Rails.logger.error "MagicHappeningLetterJob: No letter ID returned for project #{project.id}"
    end
  rescue => e
    Rails.logger.error "MagicHappeningLetterJob: Failed to send letter for project #{project.id}: #{e.message}"
    raise e
  end
end
