# Recreated migration from production database
# Original migration file was lost but existed in production schema_migrations table
# See: https://hackclub.slack.com/archives/C09KCFWQSKE/p1769100073154269
class AddOverallScoresToPostShipEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :post_ship_events, :overall_score, :numeric unless column_exists?(:post_ship_events, :overall_score)
    add_column :post_ship_events, :overall_percentile, :numeric unless column_exists?(:post_ship_events, :overall_percentile)
  end
end
