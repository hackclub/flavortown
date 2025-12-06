class AddTutorialStepsCompletedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tutorial_steps_completed, :string, array: true, default: []
  end
end
