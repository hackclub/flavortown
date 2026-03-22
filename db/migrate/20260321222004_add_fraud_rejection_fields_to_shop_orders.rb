class AddFraudRejectionFieldsToShopOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_orders, :internal_rejection_reason, :text
    add_column :shop_orders, :joe_case_url, :string
    add_column :shop_orders, :fraud_related_project_id, :bigint
  end
end
