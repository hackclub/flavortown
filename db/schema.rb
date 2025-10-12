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

ActiveRecord::Schema[8.0].define(version: 2025_10_12_163753) do
  create_table "user_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider"
    t.string "uid"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "access_token_ciphertext"
    t.text "refresh_token_ciphertext"
    t.string "access_token_bidx"
    t.string "refresh_token_bidx"
    t.index ["access_token_bidx"], name: "index_user_identities_on_access_token_bidx"
    t.index ["provider", "uid"], name: "index_user_identities_on_provider_and_uid", unique: true
    t.index ["refresh_token_bidx"], name: "index_user_identities_on_refresh_token_bidx"
    t.index ["user_id", "provider"], name: "index_user_identities_on_user_id_and_provider", unique: true
    t.index ["user_id"], name: "index_user_identities_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "display_name"
    t.integer "projects_count"
    t.integer "votes_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "user_identities", "users"
end
