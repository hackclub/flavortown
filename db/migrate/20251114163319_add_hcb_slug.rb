class AddHCBSlug < ActiveRecord::Migration[8.1]
  def change
    add_column :hcb_credentials, :slug, :string
  end
end
