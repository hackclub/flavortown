class AddProjectAndUserToPosts < ActiveRecord::Migration[8.0]
    def change
      add_reference :posts, :project, null: false, foreign_key: true
      add_reference :posts, :user, foreign_key: true
    end
end
