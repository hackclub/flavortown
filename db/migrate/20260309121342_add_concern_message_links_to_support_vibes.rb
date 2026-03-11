class AddConcernMessageLinksToSupportVibes < ActiveRecord::Migration[8.1]
  def change
    add_column :support_vibes, :concern_message_links, :jsonb
  end
end
