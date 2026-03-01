class AddManualYswsOverrideToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :manual_ysws_override, :boolean
  end
end
