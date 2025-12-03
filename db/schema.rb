# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_03_145919) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message_checksum", null: false
    t.string "message_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "blazer_audits", force: :cascade do |t|
    t.datetime "created_at"
    t.string "data_source"
    t.bigint "query_id"
    t.text "statement"
    t.bigint "user_id"
    t.index ["created_at"], name: "index_blazer_audits_on_created_at"
    t.index ["query_id"], name: "index_blazer_audits_on_query_id"
    t.index ["user_id"], name: "index_blazer_audits_on_user_id"
  end

  create_table "blazer_checks", force: :cascade do |t|
    t.string "check_type"
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.text "emails"
    t.datetime "last_run_at"
    t.text "message"
    t.bigint "query_id"
    t.string "schedule"
    t.text "slack_channels"
    t.string "state"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_checks_on_creator_id"
    t.index ["query_id"], name: "index_blazer_checks_on_query_id"
  end

  create_table "blazer_dashboard_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "dashboard_id"
    t.integer "position"
    t.bigint "query_id"
    t.datetime "updated_at", null: false
    t.index ["dashboard_id"], name: "index_blazer_dashboard_queries_on_dashboard_id"
    t.index ["query_id"], name: "index_blazer_dashboard_queries_on_query_id"
  end

  create_table "blazer_dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_dashboards_on_creator_id"
  end

  create_table "blazer_queries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id"
    t.string "data_source"
    t.text "description"
    t.string "name"
    t.text "statement"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_blazer_queries_on_creator_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "hcb_credentials", force: :cascade do |t|
    t.text "access_token_ciphertext"
    t.string "base_url"
    t.string "client_id"
    t.text "client_secret_ciphertext"
    t.datetime "created_at", null: false
    t.string "redirect_uri"
    t.text "refresh_token_ciphertext"
    t.string "slug"
    t.datetime "updated_at", null: false
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.integer "amount"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.bigint "ledgerable_id", null: false
    t.string "ledgerable_type", null: false
    t.string "reason"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_ledger_entries_on_created_by_id"
    t.index ["ledgerable_type", "ledgerable_id"], name: "index_ledger_entries_on_ledgerable"
  end

  create_table "post_devlogs", force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "post_ship_events", force: :cascade do |t|
    t.string "body"
    t.datetime "created_at", null: false
    t.float "hours"
    t.float "multiplier"
    t.float "payout"
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "postable_id"
    t.string "postable_type"
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["project_id"], name: "index_posts_on_project_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "project_ideas", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "model", null: false
    t.text "prompt", null: false
    t.datetime "updated_at", null: false
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.integer "role"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "demo_url"
    t.text "description"
    t.integer "memberships_count", default: 0, null: false
    t.text "readme_url"
    t.text "repo_url"
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rsvps", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "ip_address"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
  end

  create_table "shop_card_grants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expected_amount_cents"
    t.string "hcb_grant_hashid"
    t.bigint "shop_item_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["shop_item_id"], name: "index_shop_card_grants_on_shop_item_id"
    t.index ["user_id"], name: "index_shop_card_grants_on_user_id"
  end

  create_table "shop_items", force: :cascade do |t|
    t.jsonb "agh_contents"
    t.datetime "created_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "description"
    t.boolean "enabled"
    t.boolean "enabled_au"
    t.boolean "enabled_ca"
    t.boolean "enabled_eu"
    t.boolean "enabled_in"
    t.boolean "enabled_uk"
    t.boolean "enabled_us"
    t.boolean "enabled_xx"
    t.integer "hacker_score"
    t.string "hcb_category_lock"
    t.string "hcb_keyword_lock"
    t.string "hcb_merchant_lock"
    t.text "hcb_preauthorization_instructions"
    t.string "internal_description"
    t.boolean "limited"
    t.integer "max_qty"
    t.string "name"
    t.boolean "one_per_person_ever"
    t.integer "payout_percentage", default: 0
    t.decimal "price_offset_au"
    t.decimal "price_offset_ca"
    t.decimal "price_offset_eu"
    t.decimal "price_offset_in"
    t.decimal "price_offset_uk", precision: 10, scale: 2
    t.decimal "price_offset_us"
    t.decimal "price_offset_xx"
    t.integer "sale_percentage"
    t.boolean "show_in_carousel"
    t.integer "site_action"
    t.boolean "special"
    t.integer "stock"
    t.decimal "ticket_cost"
    t.string "type"
    t.date "unlock_on"
    t.datetime "updated_at", precision: nil, default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.decimal "usd_cost"
    t.bigint "user_id"
    t.index ["user_id"], name: "index_shop_items_on_user_id"
  end

  create_table "shop_orders", force: :cascade do |t|
    t.string "aasm_state"
    t.datetime "awaiting_periodical_fulfillment_at"
    t.datetime "created_at", null: false
    t.string "external_ref"
    t.text "frozen_address_ciphertext"
    t.decimal "frozen_item_price", precision: 6, scale: 2
    t.datetime "fulfilled_at"
    t.string "fulfilled_by"
    t.decimal "fulfillment_cost", precision: 6, scale: 2, default: "0.0"
    t.text "internal_notes"
    t.datetime "on_hold_at"
    t.integer "quantity"
    t.datetime "rejected_at"
    t.string "rejection_reason"
    t.bigint "shop_card_grant_id"
    t.bigint "shop_item_id", null: false
    t.string "tracking_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "warehouse_package_id"
    t.index ["shop_item_id", "aasm_state", "quantity"], name: "idx_shop_orders_item_state_qty"
    t.index ["shop_item_id", "aasm_state"], name: "idx_shop_orders_stock_calc"
    t.index ["shop_item_id"], name: "index_shop_orders_on_shop_item_id"
    t.index ["user_id", "shop_item_id", "aasm_state"], name: "idx_shop_orders_user_item_state"
    t.index ["user_id", "shop_item_id"], name: "idx_shop_orders_user_item_unique"
    t.index ["user_id"], name: "index_shop_orders_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "user_hackatime_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "project_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_user_hackatime_projects_on_project_id"
    t.index ["user_id", "name"], name: "index_user_hackatime_projects_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_user_hackatime_projects_on_user_id"
  end

  create_table "user_identities", force: :cascade do |t|
    t.string "access_token_bidx"
    t.text "access_token_ciphertext"
    t.datetime "created_at", null: false
    t.string "provider"
    t.string "refresh_token_bidx"
    t.text "refresh_token_ciphertext"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["access_token_bidx"], name: "index_user_identities_on_access_token_bidx"
    t.index ["provider", "uid"], name: "index_user_identities_on_provider_and_uid", unique: true
    t.index ["refresh_token_bidx"], name: "index_user_identities_on_refresh_token_bidx"
    t.index ["user_id", "provider"], name: "index_user_identities_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identities_on_user_id"
  end

  create_table "user_role_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_user_role_assignments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email"
    t.string "first_name"
    t.boolean "has_gotten_free_stickers", default: false
    t.boolean "has_roles", default: true, null: false
    t.string "last_name"
    t.string "magic_link_token"
    t.datetime "magic_link_token_expires_at"
    t.integer "projects_count"
    t.string "region"
    t.string "slack_id"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.string "verification_status", default: "needs_submission", null: false
    t.integer "votes_count"
    t.index ["email"], name: "index_users_on_email"
    t.index ["magic_link_token"], name: "index_users_on_magic_link_token", unique: true
    t.index ["region"], name: "index_users_on_region"
    t.index ["slack_id"], name: "index_users_on_slack_id", unique: true
  end

  create_table "versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.string "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "votes", force: :cascade do |t|
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.boolean "demo_url_clicked"
    t.bigint "project_id", null: false
    t.boolean "repo_url_clicked"
    t.integer "score", null: false
    t.integer "time_taken_to_vote"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_votes_on_project_id"
    t.index ["user_id", "project_id", "category"], name: "index_votes_on_user_id_and_project_id_and_category", unique: true
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ledger_entries", "users", column: "created_by_id"
  add_foreign_key "posts", "projects"
  add_foreign_key "posts", "users"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "shop_card_grants", "shop_items"
  add_foreign_key "shop_card_grants", "users"
  add_foreign_key "shop_items", "users"
  add_foreign_key "shop_orders", "shop_items"
  add_foreign_key "shop_orders", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_hackatime_projects", "projects"
  add_foreign_key "user_hackatime_projects", "users"
  add_foreign_key "user_identities", "users"
  add_foreign_key "user_role_assignments", "users"
  add_foreign_key "votes", "projects"
  add_foreign_key "votes", "users"
end
