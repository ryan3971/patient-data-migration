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

ActiveRecord::Schema[8.1].define(version: 2026_04_26_200627) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "import_failures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "failure_reason"
    t.string "health_number"
    t.string "health_number_province"
    t.bigint "import_id", null: false
    t.integer "row_number", null: false
    t.datetime "updated_at", null: false
    t.index ["import_id"], name: "index_import_failures_on_import_id"
  end

  create_table "imports", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.text "error_message"
    t.integer "failed_count", default: 0, null: false
    t.string "filename"
    t.integer "skipped_count", default: 0, null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "total_rows"
    t.datetime "updated_at", null: false
  end

  create_table "patients", force: :cascade do |t|
    t.string "address_city"
    t.string "address_line_1"
    t.string "address_line_2"
    t.string "address_postal_code"
    t.string "address_province"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "email"
    t.string "first_name"
    t.string "health_number", null: false
    t.string "health_number_province", null: false
    t.integer "import_id", null: false
    t.string "last_name"
    t.string "middle_name"
    t.string "phone_number"
    t.string "sex"
    t.datetime "updated_at", null: false
    t.index ["health_number", "health_number_province"], name: "index_patients_on_health_number_and_province", unique: true
    t.index ["import_id"], name: "index_patients_on_import_id"
  end

  add_foreign_key "import_failures", "imports"
  add_foreign_key "patients", "imports"
end
