class AddUserAgentAndIpAddressToRsvps < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :user_agent, :string
    add_column :rsvps, :ip_address, :string
  end
end
