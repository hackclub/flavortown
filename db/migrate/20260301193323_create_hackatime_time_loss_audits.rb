class CreateHackatimeTimeLossAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :hackatime_time_loss_audits do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :per_project_sum_seconds, null: false, default: 0
      t.integer :ungrouped_total_seconds, null: false, default: 0
      t.integer :devlog_total_seconds, null: false, default: 0
      t.integer :difference_seconds, null: false, default: 0
      t.text :hackatime_keys, null: false, default: ""
      t.datetime :audited_at, null: false

      t.timestamps
    end

    add_index :hackatime_time_loss_audits, :difference_seconds
    add_index :hackatime_time_loss_audits, :audited_at
  end
end
