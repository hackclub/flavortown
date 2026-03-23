class SeedConvergeSidequest < ActiveRecord::Migration[8.0]
  def up
    Sidequest.find_or_create_by!(slug: "converge") do |sq|
      sq.title = "Converge"
      sq.description = "Build a Slack or Discord bot that does something useful or creative. Ship it on Flavortown and submit it to unlock Converge prizes in the shop!"
    end
  end

  def down
    Sidequest.find_by(slug: "converge")&.destroy
  end
end
