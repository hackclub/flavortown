# frozen_string_literal: true

# This migration comes from active_insights (originally 20241016142157)
class AddUserAgentToRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :active_insights_requests, :user_agent, :string
  end
end
