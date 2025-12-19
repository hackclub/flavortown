class Airtable::ProjectSync < ApplicationJob
  queue_as :literally_whenever

  def self.perform_later(*args)
    return if SolidQueue::Job.where(class_name: name, finished_at: nil).exists?

    super
  end

  def perform
    table = Norairrecord.table(
      Rails.application.credentials&.airtable&.api_key || ENV["AIRTABLE_API_KEY"],
      Rails.application.credentials&.airtable&.base_id || ENV["AIRTABLE_BASE_ID"],
      "_projects"
    )

    records = projects_to_sync.map do |project|
      table.new({
        "title" => project.title,
        "description" => project.description,
        "repo_url" => project.repo_url,
        "demo_url" => project.demo_url,
        "readme_url" => project.readme_url,
        "ship_status" => project.ship_status,
        "shipped_at" => project.shipped_at,
        "is_fire" => project.marked_fire_at.present?,
        "marked_fire_at" => project.marked_fire_at,
        "created_at" => project.created_at,
        "synced_at" => Time.now,
        "flavor_id" => project.id
      })
    end

    table.batch_upsert(records, "flavor_id")
  ensure
    projects_to_sync.update_all(synced_at: Time.now)
  end

  private

  def projects_to_sync
    @projects_to_sync ||= Project.unscoped.where(deleted_at: nil).order("synced_at ASC NULLS FIRST").limit(10)
  end
end
