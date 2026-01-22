# Recreated migration from production database
# Original migration file was lost but existed in production schema_migrations table
# See: https://hackclub.slack.com/archives/C09KCFWQSKE/p1769100073154269
class AddVotingScoresToPostShipEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :post_ship_events, :originality_median, :numeric unless column_exists?(:post_ship_events, :originality_median)
    add_column :post_ship_events, :originality_percentile, :numeric unless column_exists?(:post_ship_events, :originality_percentile)
    add_column :post_ship_events, :technical_median, :numeric unless column_exists?(:post_ship_events, :technical_median)
    add_column :post_ship_events, :technical_percentile, :numeric unless column_exists?(:post_ship_events, :technical_percentile)
    add_column :post_ship_events, :usability_median, :numeric unless column_exists?(:post_ship_events, :usability_median)
    add_column :post_ship_events, :usability_percentile, :numeric unless column_exists?(:post_ship_events, :usability_percentile)
    add_column :post_ship_events, :storytelling_median, :numeric unless column_exists?(:post_ship_events, :storytelling_median)
    add_column :post_ship_events, :storytelling_percentile, :numeric unless column_exists?(:post_ship_events, :storytelling_percentile)
  end
end
