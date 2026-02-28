class CreateShowAndTellPayoutRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :show_and_tell_payout_records do |t|
      t.date :date, null: false
      t.references :payout_given_by, foreign_key: { to_table: :users }, null: false
      t.text :notes

      t.timestamps
    end

    add_index :show_and_tell_payout_records, :date, unique: true
  end
end
