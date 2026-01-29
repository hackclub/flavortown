class AddMajorityJudgmentScoresToPostShipEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :post_ship_events, :originality_median, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :technical_median, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :usability_median, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :storytelling_median, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :overall_score, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :originality_percentile, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :technical_percentile, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :usability_percentile, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :storytelling_percentile, :decimal, precision: 5, scale: 2
    add_column :post_ship_events, :overall_percentile, :decimal, precision: 5, scale: 2
  end
end
