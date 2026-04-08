class AddVerdictColumnsToVotesAndShipEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :votes, :verdict, :string
    add_index :votes, :verdict, algorithm: :concurrently

    add_column :post_ship_events, :payout_blessing, :string
  end
end
