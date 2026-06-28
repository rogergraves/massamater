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

ActiveRecord::Schema[8.1].define(version: 2026_06_28_154958) do
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

  create_table "daily_inventories", force: :cascade do |t|
    t.boolean "added", default: false, null: false
    t.integer "batch_size", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "product_id", null: false
    t.time "ready_time_override"
    t.boolean "skipped", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "date"], name: "index_daily_inventories_on_product_id_and_date", unique: true
    t.index ["product_id"], name: "index_daily_inventories_on_product_id"
  end

  create_table "product_schedule_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.integer "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "day_of_week"], name: "index_product_schedule_days_on_product_id_and_day_of_week", unique: true
    t.index ["product_id"], name: "index_product_schedule_days_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "default_daily_batch_size", null: false
    t.time "default_ready_time", null: false
    t.integer "max_reservable_quantity_per_client"
    t.string "name", null: false
    t.string "name_en"
    t.integer "order", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "reservation_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "product_id", null: false
    t.integer "quantity", null: false
    t.integer "reservation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_reservation_items_on_product_id"
    t.index ["reservation_id", "product_id"], name: "index_reservation_items_on_reservation_id_and_product_id", unique: true
    t.index ["reservation_id"], name: "index_reservation_items_on_reservation_id"
  end

  create_table "reservations", force: :cascade do |t|
    t.boolean "cancelled", default: false, null: false
    t.datetime "collected_at"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "note"
    t.time "pickup_time"
    t.integer "source", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "store_exceptions", force: :cascade do |t|
    t.boolean "closed", default: true, null: false
    t.time "closes_at"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.time "opens_at"
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_store_exceptions_on_date", unique: true
  end

  create_table "store_hours", force: :cascade do |t|
    t.time "closes_at"
    t.datetime "created_at", null: false
    t.integer "day_of_week", null: false
    t.boolean "open", default: true, null: false
    t.time "opens_at"
    t.datetime "updated_at", null: false
    t.index ["day_of_week"], name: "index_store_hours_on_day_of_week", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.integer "contact_channel", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.string "phone", null: false
    t.datetime "updated_at", null: false
    t.index ["phone"], name: "index_users_on_phone", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "daily_inventories", "products"
  add_foreign_key "product_schedule_days", "products"
  add_foreign_key "reservation_items", "products"
  add_foreign_key "reservation_items", "reservations"
  add_foreign_key "reservations", "users"
end
