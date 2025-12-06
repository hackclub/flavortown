# frozen_string_literal: true

# This migration comes from active_insights (originally 20241015142450)
class AddIpAddressToRequests < ActiveRecord::Migration[7.1]
  def change
    add_column :active_insights_requests, :ip_address, :string
  end
end
