# app/models/import_row.rb

class ImportFailure < ApplicationRecord
  belongs_to :import

  validates :row_number,      presence: true
  validates :failure_reason,  presence: true
end