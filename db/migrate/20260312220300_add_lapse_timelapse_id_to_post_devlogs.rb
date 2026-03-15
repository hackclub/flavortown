class AddLapseTimelapseIdToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :lapse_timelapse_id, :string
  end
end
