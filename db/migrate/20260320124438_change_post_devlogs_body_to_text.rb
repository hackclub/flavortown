class ChangePostDevlogsBodyToText < ActiveRecord::Migration[8.1]
  def up
    # Changing from varchar/string -> text is safe on Postgres (no data loss,
    # no rewrite required). Wrap in `safety_assured` so StrongMigrations doesn't complain.
    safety_assured do
      change_column :post_devlogs, :body, :text
    end
  end

  def down
    safety_assured do
      change_column :post_devlogs, :body, :string, limit: 255
    end
  end
end
