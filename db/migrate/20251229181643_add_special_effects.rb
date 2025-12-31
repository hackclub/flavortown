class AddSpecialEffects < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :special_effects_enabled, :boolean, default: true, null: false
  end
end
