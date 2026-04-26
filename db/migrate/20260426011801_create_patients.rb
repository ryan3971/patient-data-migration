class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.references :import,                  null: false, foreign_key: true
      t.string     :health_number,           null: false
      t.string     :health_number_province,  null: false
      t.string     :first_name
      t.string     :last_name
      t.string     :middle_name
      t.date       :date_of_birth
      t.string     :sex
      t.string     :phone_number
      t.string     :email
      t.string     :address_line_1
      t.string     :address_line_2
      t.string     :address_city
      t.string     :address_province
      t.string     :address_postal_code

      t.timestamps
    end

    add_index :patients,
              [:health_number, :health_number_province],
              unique: true,
              name: 'index_patients_on_health_number_and_province'
  end
end
