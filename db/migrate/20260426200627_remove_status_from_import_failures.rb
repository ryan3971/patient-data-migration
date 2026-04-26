class RemoveStatusFromImportFailures < ActiveRecord::Migration[8.1]
  def change
    remove_column :import_failures, :status, :integer
  end
end
