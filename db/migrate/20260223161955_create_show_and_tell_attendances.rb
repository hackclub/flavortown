class CreateShowAndTellAttendances < ActiveRecord::Migration[8.1]
  def change
    create_table :show_and_tell_attendances do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date

      t.timestamps
    end
  end
end
