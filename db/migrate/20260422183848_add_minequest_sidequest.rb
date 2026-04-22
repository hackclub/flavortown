class AddMinequestSidequest < ActiveRecord::Migration[8.1]
  def up
    Sidequest.create!(
      title: "Minequest",
      slug: "minequest",
      description: "Build a Minecraft-related project! Create mods, tools, maps, data packs, or anything code-related in the Minecraft ecosystem.",
      external_page_link: nil,
      expires_at: nil
    )
  end

  def down
    Sidequest.find_by(slug: "minequest")&.destroy
  end
end
