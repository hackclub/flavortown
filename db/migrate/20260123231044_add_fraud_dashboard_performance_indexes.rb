class AddFraudDashboardPerformanceIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :project_reports, [ :status, :created_at ],
              order: { created_at: :desc },
              name: "idx_project_reports_status_created_at_desc",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :shop_orders, [ :aasm_state, :created_at ],
              order: { created_at: :desc },
              name: "idx_shop_orders_aasm_state_created_at_desc",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :versions, [ :item_id, :created_at ],
              where: "item_type = 'Project::Report' AND (object_changes ? 'status')",
              name: "idx_versions_project_report_status",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :versions, [ :item_id, :created_at ],
              where: "item_type = 'ShopOrder' AND (object_changes ? 'aasm_state')",
              name: "idx_versions_shop_order_aasm_state",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
