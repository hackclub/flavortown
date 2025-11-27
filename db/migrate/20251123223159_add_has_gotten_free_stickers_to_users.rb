class AddHasGottenFreeStickersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :has_gotten_free_stickers, :boolean, default: false
  end
end
