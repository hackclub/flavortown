class Airtable::ProjectSyncJob < Airtable::BaseSyncJob
  def table_name = "_projects"

  def records = Project.unscoped.where(deleted_at: nil)

  def field_mapping(project)
    {
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
      "flavor_id" => project.id.to_s
    }
  end
end
