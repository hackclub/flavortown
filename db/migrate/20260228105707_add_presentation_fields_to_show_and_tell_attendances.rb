class AddPresentationFieldsToShowAndTellAttendances < ActiveRecord::Migration[8.1]
  def change
    add_reference :show_and_tell_attendances, :project, foreign_key: true, null: true
    add_column :show_and_tell_attendances, :give_presentation_payout, :boolean, default: false, null: false
    add_column :show_and_tell_attendances, :payout_given, :boolean, default: false, null: false
    add_column :show_and_tell_attendances, :payout_given_at, :datetime
    add_reference :show_and_tell_attendances, :payout_given_by, foreign_key: { to_table: :users }, null: true
    add_column :show_and_tell_attendances, :winner, :boolean, default: false, null: false
    add_column :show_and_tell_attendances, :winner_payout_given, :boolean, default: false, null: false
  end
end
