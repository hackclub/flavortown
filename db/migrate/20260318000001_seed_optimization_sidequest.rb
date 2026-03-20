class SeedOptimizationSidequest < ActiveRecord::Migration[8.1]
  def up
    Sidequest.find_or_create_by!(slug: "optimization") do |sq|
      sq.title = "Optimization"
      sq.description = "Build and ship a project for the Optimization sidequest to unlock Optimization prizes in the shop."
    end
  end

  def down
    Sidequest.find_by(slug: "optimization")&.destroy
  end
end
