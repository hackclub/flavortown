# frozen_string_literal: true

# This migration comes from active_insights (originally 20240111225806)
class CreateActiveInsightsTables < ActiveRecord::Migration[7.1]
  def change
    create_table :active_insights_requests, if_not_exists: true do |t|
      t.string :controller
      t.string :action
      t.string :format
      t.string :http_method
      t.text :path
      t.integer :status
      t.float :view_runtime
      t.float :db_runtime
      t.datetime :started_at
      t.datetime :finished_at
      t.string :uuid
      t.float :duration
      case connection.adapter_name
      when "Mysql2", "Mysql2Spatial", "Mysql2Rgeo", "Trilogy"
        t.virtual :formatted_controller, type: :string, as: "CONCAT(controller, '#', action)", stored: true
      else
        t.virtual :formatted_controller, type: :string, as: "controller || '#'|| action", stored: true
      end

      t.index :started_at
      t.index %i(started_at duration)
      t.index %i(started_at formatted_controller)

      t.timestamps
    end

    create_table :active_insights_jobs, if_not_exists: true do |t|
      t.string :job
      t.string :queue
      t.float :db_runtime
      t.datetime :scheduled_at
      t.datetime :started_at
      t.datetime :finished_at
      t.string :uuid
      t.float :duration
      t.float :queue_time

      t.index :started_at
      t.index %i(started_at duration)
      t.index %i(started_at duration queue_time)

      t.timestamps
    end
  end
end
