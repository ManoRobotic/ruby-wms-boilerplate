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

ActiveRecord::Schema[8.0].define(version: 2025_08_27_032206) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "address"
    t.boolean "google_sheets_enabled"
    t.text "google_credentials"
    t.string "sheet_id"
    t.string "worksheet_gid"
    t.datetime "last_sync_at"
    t.string "last_sync_checksum"
    t.integer "total_orders_synced"
    t.string "super_admin_role"
    t.string "serial_port"
    t.integer "serial_baud_rate"
    t.string "serial_parity"
    t.integer "serial_stop_bits"
    t.integer "serial_data_bits"
    t.uuid "empresa_id"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["empresa_id"], name: "index_admins_on_empresa_id"
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
    t.index ["super_admin_role"], name: "index_admins_on_super_admin_role"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image"
    t.string "image_url"
  end

  create_table "coins", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "selling_price"
    t.decimal "purchase_price"
  end

  create_table "cycle_count_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "cycle_count_id", null: false
    t.uuid "product_id", null: false
    t.integer "system_quantity"
    t.integer "counted_quantity"
    t.integer "variance"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cycle_count_id"], name: "index_cycle_count_items_on_cycle_count_id"
    t.index ["product_id"], name: "index_cycle_count_items_on_product_id"
  end

  create_table "cycle_counts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "warehouse_id", null: false
    t.uuid "admin_id", null: false
    t.uuid "location_id", null: false
    t.string "status"
    t.date "scheduled_date"
    t.date "completed_date"
    t.string "count_type"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_cycle_counts_on_admin_id"
    t.index ["location_id", "status"], name: "idx_cycle_counts_location_status"
    t.index ["location_id"], name: "index_cycle_counts_on_location_id"
    t.index ["scheduled_date", "status"], name: "idx_cycle_counts_scheduled_status"
    t.index ["warehouse_id", "status"], name: "idx_cycle_counts_warehouse_status"
    t.index ["warehouse_id"], name: "index_cycle_counts_on_warehouse_id"
  end

  create_table "empresas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "inventory_codes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "no_ordp", null: false
    t.string "cve_copr"
    t.string "cve_prod"
    t.decimal "can_copr", precision: 12, scale: 6
    t.integer "tip_copr"
    t.decimal "costo", precision: 12, scale: 8
    t.date "fech_cto"
    t.string "cve_suc"
    t.integer "trans"
    t.string "lote"
    t.string "new_med"
    t.string "new_copr"
    t.decimal "costo_rep", precision: 12, scale: 8
    t.integer "partresp"
    t.string "dmov"
    t.integer "partop"
    t.decimal "fcdres", precision: 12, scale: 6
    t.string "undres"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cve_copr"], name: "index_inventory_codes_on_cve_copr"
    t.index ["cve_prod"], name: "index_inventory_codes_on_cve_prod"
    t.index ["fech_cto"], name: "index_inventory_codes_on_fech_cto"
    t.index ["lote"], name: "index_inventory_codes_on_lote"
    t.index ["no_ordp"], name: "index_inventory_codes_on_no_ordp"
  end

  create_table "inventory_transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "warehouse_id", null: false
    t.uuid "location_id"
    t.uuid "product_id", null: false
    t.string "transaction_type", null: false
    t.integer "quantity", null: false
    t.decimal "unit_cost", precision: 10, scale: 2
    t.string "reference_type"
    t.uuid "reference_id"
    t.uuid "admin_id", null: false
    t.text "reason"
    t.string "batch_number", limit: 50
    t.date "expiry_date"
    t.string "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id", "created_at"], name: "idx_inventory_transactions_admin_date"
    t.index ["admin_id"], name: "index_inventory_transactions_on_admin_id"
    t.index ["batch_number"], name: "idx_inventory_transactions_batch", where: "(batch_number IS NOT NULL)"
    t.index ["batch_number"], name: "index_inventory_transactions_on_batch_number"
    t.index ["created_at"], name: "index_inventory_transactions_on_created_at"
    t.index ["location_id", "created_at"], name: "idx_inventory_transactions_location_date"
    t.index ["location_id"], name: "index_inventory_transactions_on_location_id"
    t.index ["product_id", "created_at"], name: "idx_inventory_transactions_product_date"
    t.index ["product_id"], name: "index_inventory_transactions_on_product_id"
    t.index ["reference_type", "reference_id"], name: "idx_on_reference_type_reference_id_30e938d718"
    t.index ["transaction_type", "created_at"], name: "idx_inventory_transactions_type_date"
    t.index ["transaction_type"], name: "index_inventory_transactions_on_transaction_type"
    t.index ["warehouse_id", "created_at"], name: "idx_inventory_transactions_warehouse_date"
    t.index ["warehouse_id"], name: "index_inventory_transactions_on_warehouse_id"
  end

  create_table "locations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "zone_id", null: false
    t.string "aisle", limit: 10, null: false
    t.string "bay", limit: 10, null: false
    t.string "level", limit: 10, null: false
    t.string "position", limit: 10, null: false
    t.string "barcode", limit: 50
    t.string "location_type", default: "bin", null: false
    t.integer "capacity", default: 100
    t.integer "current_volume", default: 0
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_locations_on_active"
    t.index ["aisle", "bay", "level"], name: "idx_locations_position"
    t.index ["barcode"], name: "idx_locations_barcode", where: "(barcode IS NOT NULL)"
    t.index ["barcode"], name: "index_locations_on_barcode", unique: true, where: "(barcode IS NOT NULL)"
    t.index ["current_volume", "capacity"], name: "idx_locations_utilization"
    t.index ["location_type"], name: "index_locations_on_location_type"
    t.index ["zone_id", "aisle", "bay", "level", "position"], name: "index_locations_on_coordinates", unique: true
    t.index ["zone_id"], name: "idx_locations_zone"
    t.index ["zone_id"], name: "index_locations_on_zone_id"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.string "notification_type", null: false
    t.datetime "read_at"
    t.text "data"
    t.string "action_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["read_at"], name: "index_notifications_on_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "order_products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.uuid "order_id", null: false
    t.string "size", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.index ["order_id"], name: "index_order_products_on_order_id"
    t.index ["product_id"], name: "index_order_products_on_product_id"
  end

  create_table "orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "customer_email", null: false
    t.boolean "fulfilled"
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.text "address", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_id"
    t.integer "status", default: 0, null: false
    t.uuid "warehouse_id"
    t.string "order_type", default: "sales_order"
    t.string "fulfillment_status", default: "pending"
    t.date "requested_ship_date"
    t.date "shipped_date"
    t.string "tracking_number", limit: 100
    t.string "priority", default: "medium"
    t.text "notes"
    t.uuid "wave_id"
    t.index ["fulfillment_status"], name: "index_orders_on_fulfillment_status"
    t.index ["order_type"], name: "index_orders_on_order_type"
    t.index ["payment_id"], name: "index_orders_on_payment_id"
    t.index ["priority"], name: "index_orders_on_priority"
    t.index ["requested_ship_date"], name: "index_orders_on_requested_ship_date"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["warehouse_id"], name: "index_orders_on_warehouse_id"
    t.index ["wave_id", "status"], name: "index_orders_on_wave_id_and_status"
    t.index ["wave_id"], name: "index_orders_on_wave_id"
  end

  create_table "packing_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "lote_padre"
    t.string "lote"
    t.string "cve_prod"
    t.decimal "peso_bruto", precision: 10, scale: 3
    t.decimal "peso_neto", precision: 10, scale: 3
    t.decimal "metros_lineales", precision: 10, scale: 2
    t.string "nombre"
    t.uuid "production_order_id", null: false
    t.integer "consecutivo"
    t.string "descripcion"
    t.string "cliente"
    t.string "num_orden"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "micras"
    t.integer "ancho_mm"
    t.index ["cve_prod"], name: "index_packing_records_on_cve_prod"
    t.index ["lote"], name: "index_packing_records_on_lote"
    t.index ["lote_padre"], name: "index_packing_records_on_lote_padre"
    t.index ["production_order_id", "consecutivo"], name: "index_packing_records_on_production_order_id_and_consecutivo"
    t.index ["production_order_id"], name: "index_packing_records_on_production_order_id"
  end

  create_table "pick_list_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "pick_list_id", null: false
    t.uuid "product_id", null: false
    t.uuid "location_id", null: false
    t.integer "quantity_requested", null: false
    t.integer "quantity_picked", default: 0
    t.string "status", default: "pending", null: false
    t.integer "sequence", null: false
    t.string "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "status"], name: "idx_pick_list_items_location_status"
    t.index ["location_id"], name: "index_pick_list_items_on_location_id"
    t.index ["pick_list_id", "location_id", "sequence"], name: "idx_pick_list_items_route_optimization"
    t.index ["pick_list_id", "sequence"], name: "idx_pick_list_items_sequence"
    t.index ["pick_list_id", "sequence"], name: "index_pick_list_items_on_pick_list_id_and_sequence"
    t.index ["pick_list_id"], name: "index_pick_list_items_on_pick_list_id"
    t.index ["product_id", "status"], name: "idx_pick_list_items_product_status"
    t.index ["product_id"], name: "index_pick_list_items_on_product_id"
    t.index ["status", "sequence"], name: "idx_pick_list_items_status_sequence"
    t.index ["status"], name: "index_pick_list_items_on_status"
  end

  create_table "pick_lists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "admin_id", null: false
    t.uuid "order_id", null: false
    t.uuid "warehouse_id", null: false
    t.string "status", default: "pending", null: false
    t.string "priority", default: "medium", null: false
    t.integer "total_items", default: 0
    t.integer "picked_items", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.string "pick_list_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "wave_id"
    t.index ["admin_id", "status"], name: "idx_pick_lists_admin_status"
    t.index ["admin_id"], name: "index_pick_lists_on_admin_id"
    t.index ["order_id"], name: "idx_pick_lists_order"
    t.index ["order_id"], name: "index_pick_lists_on_order_id"
    t.index ["pick_list_number"], name: "index_pick_lists_on_pick_list_number", unique: true
    t.index ["priority"], name: "index_pick_lists_on_priority"
    t.index ["started_at"], name: "idx_pick_lists_started_at", where: "(started_at IS NOT NULL)"
    t.index ["started_at"], name: "index_pick_lists_on_started_at"
    t.index ["status", "priority", "created_at"], name: "idx_pick_lists_status_priority_date"
    t.index ["status"], name: "index_pick_lists_on_status"
    t.index ["warehouse_id", "status"], name: "idx_pick_lists_warehouse_status"
    t.index ["warehouse_id"], name: "index_pick_lists_on_warehouse_id"
    t.index ["wave_id", "status"], name: "index_pick_lists_on_wave_id_and_status"
    t.index ["wave_id"], name: "index_pick_lists_on_wave_id"
  end

  create_table "production_order_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "production_order_id", null: false
    t.string "folio_consecutivo"
    t.decimal "peso_bruto"
    t.decimal "peso_neto"
    t.decimal "metros_lineales"
    t.integer "peso_core_gramos"
    t.string "status"
    t.integer "micras"
    t.integer "ancho_mm"
    t.integer "altura_cm"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cliente"
    t.string "numero_de_orden"
    t.string "nombre_cliente_numero_pedido"
    t.index ["production_order_id"], name: "index_production_order_items_on_production_order_id"
  end

  create_table "production_orders", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "order_number", null: false
    t.string "status", default: "pending", null: false
    t.string "priority", default: "medium", null: false
    t.uuid "warehouse_id", null: false
    t.uuid "product_id", null: false
    t.uuid "admin_id"
    t.integer "quantity_requested", null: false
    t.integer "quantity_produced", default: 0
    t.datetime "start_date"
    t.datetime "end_date"
    t.datetime "estimated_completion"
    t.datetime "actual_completion"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bag_size"
    t.string "bag_measurement"
    t.integer "pieces_count"
    t.integer "package_count"
    t.string "package_measurement"
    t.decimal "peso"
    t.string "lote_referencia"
    t.string "no_opro"
    t.decimal "carga_copr"
    t.integer "ano"
    t.integer "mes"
    t.datetime "fecha_completa"
    t.string "ren_orp"
    t.string "stat_opro"
    t.integer "sheet_row_number"
    t.string "last_sheet_update"
    t.boolean "needs_update_to_sheet"
    t.uuid "empresa_id"
    t.index ["admin_id"], name: "index_production_orders_on_admin_id"
    t.index ["created_at"], name: "index_production_orders_on_created_at"
    t.index ["empresa_id"], name: "index_production_orders_on_empresa_id"
    t.index ["order_number"], name: "index_production_orders_on_order_number", unique: true
    t.index ["priority"], name: "index_production_orders_on_priority"
    t.index ["product_id"], name: "index_production_orders_on_product_id"
    t.index ["status"], name: "index_production_orders_on_status"
    t.index ["warehouse_id"], name: "index_production_orders_on_warehouse_id"
  end

  create_table "products", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.text "description", null: false
    t.decimal "price", precision: 10, scale: 2, default: "0.0", null: false
    t.uuid "category_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: false
    t.string "image_url"
    t.string "sku", limit: 50
    t.decimal "weight", precision: 8, scale: 3
    t.jsonb "dimensions", default: {}
    t.integer "reorder_point", default: 10
    t.integer "max_stock_level", default: 1000
    t.boolean "batch_tracking", default: false
    t.string "unit_of_measure", default: "unit"
    t.string "barcode", limit: 50
    t.index ["barcode"], name: "index_products_on_barcode", unique: true, where: "(barcode IS NOT NULL)"
    t.index ["batch_tracking"], name: "index_products_on_batch_tracking"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true, where: "(sku IS NOT NULL)"
  end

  create_table "receipt_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "receipt_id", null: false
    t.uuid "product_id", null: false
    t.integer "expected_quantity"
    t.integer "received_quantity"
    t.decimal "unit_cost"
    t.string "batch_number"
    t.date "expiry_date"
    t.uuid "location_id", null: false
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_receipt_items_on_location_id"
    t.index ["product_id"], name: "index_receipt_items_on_product_id"
    t.index ["receipt_id"], name: "index_receipt_items_on_receipt_id"
  end

  create_table "receipts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "warehouse_id", null: false
    t.uuid "admin_id", null: false
    t.string "supplier_name"
    t.string "reference_number"
    t.date "expected_date"
    t.date "received_date"
    t.string "status"
    t.integer "total_items"
    t.integer "received_items"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_receipts_on_admin_id"
    t.index ["received_date"], name: "idx_receipts_received_date", where: "(received_date IS NOT NULL)"
    t.index ["reference_number"], name: "idx_receipts_reference_number"
    t.index ["warehouse_id", "status"], name: "idx_receipts_warehouse_status"
    t.index ["warehouse_id"], name: "index_receipts_on_warehouse_id"
  end

  create_table "shipments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "order_id", null: false
    t.uuid "warehouse_id", null: false
    t.uuid "admin_id", null: false
    t.string "tracking_number"
    t.string "carrier"
    t.string "status"
    t.date "shipped_date"
    t.date "delivered_date"
    t.decimal "total_weight"
    t.decimal "shipping_cost"
    t.jsonb "recipient_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_shipments_on_admin_id"
    t.index ["order_id"], name: "index_shipments_on_order_id"
    t.index ["shipped_date"], name: "idx_shipments_shipped_date", where: "(shipped_date IS NOT NULL)"
    t.index ["tracking_number"], name: "idx_shipments_tracking_number"
    t.index ["warehouse_id", "status"], name: "idx_shipments_warehouse_status"
    t.index ["warehouse_id"], name: "index_shipments_on_warehouse_id"
  end

  create_table "stocks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "product_id", null: false
    t.integer "amount", default: 0
    t.string "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "location_id"
    t.string "batch_number", limit: 50
    t.date "expiry_date"
    t.integer "reserved_quantity", default: 0
    t.decimal "unit_cost", precision: 10, scale: 2
    t.date "received_date"
    t.index ["batch_number"], name: "index_stocks_on_batch_number"
    t.index ["expiry_date"], name: "index_stocks_on_expiry_date"
    t.index ["location_id"], name: "index_stocks_on_location_id"
    t.index ["product_id", "location_id", "batch_number"], name: "index_stocks_on_product_location_batch"
    t.index ["product_id"], name: "index_stocks_on_product_id"
  end

  create_table "tasks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "admin_id", null: false
    t.string "task_type", null: false
    t.string "priority", default: "medium", null: false
    t.string "status", default: "pending", null: false
    t.uuid "warehouse_id", null: false
    t.uuid "location_id"
    t.uuid "product_id"
    t.integer "quantity", default: 1
    t.text "instructions"
    t.datetime "assigned_at"
    t.datetime "completed_at"
    t.uuid "from_location_id"
    t.uuid "to_location_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id", "status"], name: "idx_tasks_admin_status"
    t.index ["admin_id"], name: "index_tasks_on_admin_id"
    t.index ["assigned_at"], name: "index_tasks_on_assigned_at"
    t.index ["from_location_id"], name: "index_tasks_on_from_location_id"
    t.index ["location_id"], name: "index_tasks_on_location_id"
    t.index ["priority"], name: "index_tasks_on_priority"
    t.index ["product_id"], name: "idx_tasks_product", where: "(product_id IS NOT NULL)"
    t.index ["product_id"], name: "index_tasks_on_product_id"
    t.index ["status", "priority", "created_at"], name: "idx_tasks_status_priority_date"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["task_type", "status"], name: "idx_tasks_type_status"
    t.index ["task_type"], name: "index_tasks_on_task_type"
    t.index ["to_location_id"], name: "index_tasks_on_to_location_id"
    t.index ["warehouse_id", "status"], name: "idx_tasks_warehouse_status"
    t.index ["warehouse_id", "task_type", "status", "priority"], name: "idx_tasks_warehouse_type_status_priority"
    t.index ["warehouse_id"], name: "index_tasks_on_warehouse_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "name", null: false
    t.string "role", default: "user", null: false
    t.boolean "active", default: true, null: false
    t.uuid "warehouse_id"
    t.text "permissions", default: "{}"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "super_admin_role"
    t.index ["active"], name: "index_users_on_active"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["warehouse_id"], name: "index_users_on_warehouse_id"
  end

  create_table "warehouses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", limit: 100, null: false
    t.string "code", limit: 20, null: false
    t.text "address", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "contact_info", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "empresa_id"
    t.index ["active"], name: "index_warehouses_on_active"
    t.index ["code"], name: "index_warehouses_on_code", unique: true
    t.index ["empresa_id"], name: "index_warehouses_on_empresa_id"
  end

  create_table "waves", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.uuid "warehouse_id", null: false
    t.string "status", default: "planning", null: false
    t.string "wave_type", default: "standard", null: false
    t.integer "priority", default: 5
    t.datetime "planned_start_time"
    t.datetime "actual_start_time"
    t.datetime "actual_end_time"
    t.integer "total_orders", default: 0
    t.integer "total_items", default: 0
    t.string "strategy", default: "zone_based"
    t.text "notes"
    t.uuid "admin_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_waves_on_admin_id"
    t.index ["priority"], name: "index_waves_on_priority"
    t.index ["status", "planned_start_time"], name: "index_waves_on_status_and_planned_start_time"
    t.index ["warehouse_id", "status"], name: "index_waves_on_warehouse_id_and_status"
    t.index ["warehouse_id"], name: "index_waves_on_warehouse_id"
  end

  create_table "zones", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "warehouse_id", null: false
    t.string "name", limit: 100, null: false
    t.string "code", limit: 20, null: false
    t.string "zone_type", limit: 50, default: "general", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["warehouse_id", "code"], name: "index_zones_on_warehouse_id_and_code", unique: true
    t.index ["warehouse_id", "zone_type"], name: "idx_zones_warehouse_type"
    t.index ["warehouse_id"], name: "idx_zones_warehouse"
    t.index ["warehouse_id"], name: "index_zones_on_warehouse_id"
    t.index ["zone_type"], name: "index_zones_on_zone_type"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "admins", "empresas"
  add_foreign_key "cycle_count_items", "cycle_counts"
  add_foreign_key "cycle_count_items", "products"
  add_foreign_key "cycle_counts", "admins"
  add_foreign_key "cycle_counts", "locations"
  add_foreign_key "cycle_counts", "warehouses"
  add_foreign_key "inventory_transactions", "admins"
  add_foreign_key "inventory_transactions", "locations"
  add_foreign_key "inventory_transactions", "products"
  add_foreign_key "inventory_transactions", "warehouses"
  add_foreign_key "locations", "zones"
  add_foreign_key "notifications", "users"
  add_foreign_key "order_products", "orders"
  add_foreign_key "order_products", "products"
  add_foreign_key "orders", "warehouses"
  add_foreign_key "orders", "waves"
  add_foreign_key "packing_records", "production_orders"
  add_foreign_key "pick_list_items", "locations"
  add_foreign_key "pick_list_items", "pick_lists"
  add_foreign_key "pick_list_items", "products"
  add_foreign_key "pick_lists", "admins"
  add_foreign_key "pick_lists", "orders"
  add_foreign_key "pick_lists", "warehouses"
  add_foreign_key "pick_lists", "waves"
  add_foreign_key "production_order_items", "production_orders"
  add_foreign_key "production_orders", "empresas"
  add_foreign_key "production_orders", "products"
  add_foreign_key "production_orders", "warehouses"
  add_foreign_key "products", "categories"
  add_foreign_key "receipt_items", "locations"
  add_foreign_key "receipt_items", "products"
  add_foreign_key "receipt_items", "receipts"
  add_foreign_key "receipts", "admins"
  add_foreign_key "receipts", "warehouses"
  add_foreign_key "shipments", "admins"
  add_foreign_key "shipments", "orders"
  add_foreign_key "shipments", "warehouses"
  add_foreign_key "stocks", "locations"
  add_foreign_key "stocks", "products"
  add_foreign_key "tasks", "locations"
  add_foreign_key "tasks", "locations", column: "from_location_id"
  add_foreign_key "tasks", "locations", column: "to_location_id"
  add_foreign_key "tasks", "products"
  add_foreign_key "tasks", "warehouses"
  add_foreign_key "users", "warehouses"
  add_foreign_key "warehouses", "empresas"
  add_foreign_key "waves", "admins"
  add_foreign_key "waves", "warehouses"
  add_foreign_key "zones", "warehouses"
end
