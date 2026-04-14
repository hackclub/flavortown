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

ActiveRecord::Schema[8.1].define(version: 2026_04_10_042037) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "vote_reason_embeddings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1536, null: false
    t.string "model_version", default: "text-embedding-3-small", null: false
    t.datetime "updated_at", null: false
    t.bigint "vote_id", null: false
    t.index ["vote_id"], name: "index_vote_reason_embeddings_on_vote_id", unique: true
  end
end
