class ChangePublicApiDefaultInUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :public_api, from: nil, to: true
  end
end
