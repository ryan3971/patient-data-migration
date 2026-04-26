# app/models/patient.rb

class Patient < ApplicationRecord
  belongs_to :import

  validates :health_number,          presence: true
  validates :health_number,          format: { 
                                      with: /\A\d+\z/, 
                                      message: 'must contain only digits' 
                                    }
  validates :health_number_province, presence: true
end