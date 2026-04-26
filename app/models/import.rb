# app/models/import.rb

class Import < ApplicationRecord
  has_many :patients,         dependent: :destroy
  has_many :import_failures,  dependent: :destroy

  enum :status, {
    pending:  0,
    running:  1,
    complete: 2,
    failed:   3
  }

  validates :status, presence: true
end