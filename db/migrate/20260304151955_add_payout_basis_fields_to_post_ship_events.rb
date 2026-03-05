class AddPayoutBasisFieldsToPostShipEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :post_ship_events, :payout_basis_percentile, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :payout_basis_overall_score, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :payout_curve_version, :string
    add_column :post_ship_events, :payout_basis_locked_at, :datetime
  end
end
