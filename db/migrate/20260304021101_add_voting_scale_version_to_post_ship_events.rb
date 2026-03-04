class AddVotingScaleVersionToPostShipEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :post_ship_events, :voting_scale_version, :integer, null: false, default: 2

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE post_ship_events
          SET voting_scale_version = 1
        SQL
      end
    end
  end
end
