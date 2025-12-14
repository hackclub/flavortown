class AddCertificationFieldsToPostShipEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :post_ship_events, :certification_status, :string, default: "pending"
    add_column :post_ship_events, :feedback_video_url, :string
    add_column :post_ship_events, :feedback_reason, :text
  end
end
