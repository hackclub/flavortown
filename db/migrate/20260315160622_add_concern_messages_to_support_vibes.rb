class AddConcernMessagesToSupportVibes < ActiveRecord::Migration[8.1]
  def change
    add_column :support_vibes, :concern_messages, :jsonb
  end
end
