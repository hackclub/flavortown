class AddLapseVideoProcessingToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :lapse_video_processing, :boolean, default: false, null: false
  end
end
