class IndexTheseusPackageId < ActiveRecord::Migration[8.1]
  def change
    add_index :warehouse_packages, :theseus_package_id, unique: true
  end
end
