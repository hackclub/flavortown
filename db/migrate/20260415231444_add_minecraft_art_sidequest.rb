class AddMinecraftArtSidequest < ActiveRecord::Migration[8.1]
  def up
    Sidequest.create!(
      title: "Minecraft Art Challenge",
      slug: "minecraft-art",
      description: "Make something code and art related to Minecraft! (Expect mods)",
      external_page_link: nil,
      expires_at: nil
    )
  end

  def down
    Sidequest.find_by(slug: "minecraft-art")&.destroy
  end
end
