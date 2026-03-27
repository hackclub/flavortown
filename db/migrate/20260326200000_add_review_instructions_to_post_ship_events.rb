class AddReviewInstructionsToPostShipEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :post_ship_events, :review_instructions, :text, if_not_exists: true
  end
end
