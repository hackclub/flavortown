class AddTutorialToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :tutorial, :boolean, default: false, null: false
  end
end
