class ChangePublicApiDefaultInUsers2 < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :public_api, true
  end
end
