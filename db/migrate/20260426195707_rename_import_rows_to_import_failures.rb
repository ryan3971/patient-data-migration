class RenameImportRowsToImportFailures < ActiveRecord::Migration[7.1]
  def change
    rename_table :import_rows, :import_failures
  end
end