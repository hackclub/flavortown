class ChangeSentByNullableOnMessages < ActiveRecord::Migration[8.1]
  def change
    change_column_null :messages, :sent_by_id, true
  end
end
