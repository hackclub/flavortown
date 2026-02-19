class AddUnresolvedQueriesToSupportVibes < ActiveRecord::Migration[8.1]
  def change
    add_column :support_vibes, :unresolved_queries, :jsonb, default: {}
  end
end
