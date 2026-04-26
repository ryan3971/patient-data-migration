class CreateImports < ActiveRecord::Migration[8.1]
  def change
    create_table :imports do |t|
      t.string   :filename
      t.integer  :total_rows
      t.integer  :status,        null: false, default: 0
      t.text     :error_message
      t.integer  :created_count, null: false, default: 0
      t.integer  :skipped_count, null: false, default: 0
      t.integer  :failed_count,  null: false, default: 0
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
