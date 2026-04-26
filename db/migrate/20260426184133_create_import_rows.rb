class CreateImportRows < ActiveRecord::Migration[8.1]
  def change
    create_table :import_rows do |t|
      t.references :import,     null: false, foreign_key: true
      t.integer    :row_number, null: false
      t.integer    :status,     null: false, default: 0
      t.string     :health_number
      t.string     :health_number_province
      t.string     :failure_reason

      t.timestamps
    end

    add_index :import_rows, [:import_id, :status]
  end
end
