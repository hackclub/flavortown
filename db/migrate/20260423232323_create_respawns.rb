class CreateRespawns < ActiveRecord::Migration[8.1]
  def change
    create_table :respawns do |t|
      t.timestamps
    end
  end
end
