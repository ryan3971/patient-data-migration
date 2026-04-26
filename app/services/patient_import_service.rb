# app/services/patient_import_service.rb

class PatientImportService
  # These are the exact CSV headers we expect, mapped to our column names.
  # If the source system changes its headers, this is the only place to update.
  HEADER_MAP = {
    'health identifier'          => :health_number,
    'health identifier province' => :health_number_province,
    'first name'                 => :first_name,
    'last name'                  => :last_name,
    'middle name'                => :middle_name,
    'phone'                      => :phone_number,
    'email'                      => :email,
    'address 1'                  => :address_line_1,
    'address 2'                  => :address_line_2,
    'address province'           => :address_province,
    'address city'               => :address_city,
    'address postal code'        => :address_postal_code,
    'date of birth'              => :date_of_birth,
    'sex'                        => :sex
  }.freeze

  # initialize is Ruby's constructor.
  # We pass the uploaded file in, and set up the instance variables we'll use.
  def initialize(file)
    @file   = file
    @import = Import.create!(
      status:   :pending,
      filename: file.original_filename
    )
  end

  # This is the single public method the controller calls.
  # It returns the @import record regardless of success or failure
  # so the controller always has something to pass to the view.
  def call
    begin
      @import.update!(started_at: Time.current, status: :running)

      csv = parse_csv
      validate_headers!(csv.headers)

      @import.update!(total_rows: csv.count)

      csv.each.with_index(2) do |row, row_number|
        process_row(row, row_number)
      end

      @import.update!(
        status:       :complete,
        completed_at: Time.current
      )

    rescue => e
      @import.update!(
        status:        :failed,
        error_message: e.message,
        completed_at:  Time.current
      )
    end

    @import
  end

  private

  # Parses the uploaded file using Ruby's built-in CSV library.
  # headers: true tells CSV to treat the first row as column names.
  # header_converters normalises the headers using our HEADER_MAP.
  def parse_csv
    CSV.parse(
      @file.read,
      headers:           true,
      header_converters: ->(header) { HEADER_MAP[header.strip] || header.strip }
    )
  end

  # Checks that every expected column is present in the file.
  # Raises an error if any are missing — this bubbles up to the rescue in call.
  def validate_headers!(headers)
    expected = HEADER_MAP.values
    actual   = headers.map(&:to_sym).compact
    missing  = expected - actual

    unless missing.empty?
      raise "Missing required columns: #{missing.join(', ')}"
    end
  end

  # Processes a single row.
  # Either creates the patient or skips them — never updates.
  def process_row(row, row_number)
    health_number          = row[:health_number]&.strip
    health_number_province = row[:health_number_province]&.strip

    # Stage 4 — validate identity fields
    # Validate identity fields — write failed import_row and move on
    if health_number.blank? || health_number_province.blank?
      record_import_failure(row_number, health_number, health_number_province,
                     'Missing health number or province')
      @import.increment!(:failed_count)
      return
    end

    # Check format — must be digits only
    unless valid_health_number?(health_number)
      record_import_failure(row_number, health_number, health_number_province,
                     "Invalid health number format: '#{health_number}' must contain only digits")
      @import.increment!(:failed_count)
      return
    end

    # Patient write is transactional — rolls back if save fails
    # import_row write is outside — survives any patient write failure
    outcome = nil

    ActiveRecord::Base.transaction do
      patient = Patient.find_or_initialize_by(
        health_number:          health_number,
        health_number_province: health_number_province
      )

      if patient.new_record?
        patient.assign_attributes(patient_attributes(row))
        patient.import_id = @import.id
        patient.save!
        outcome = :created
      else
        outcome = :skipped
      end
    end

    if outcome == :created
      @import.increment!(:created_count)
    else
      @import.increment!(:skipped_count)
    end

  rescue => e
    record_import_failure(row_number, health_number, health_number_province, e.message)
    @import.increment!(:failed_count)
  end

  def valid_health_number?(value)
    value.present? && value.match?(/\A\d+\z/)
  end

  def record_import_failure(row_number, health_number, health_number_province, reason)
    ImportFailure.create!(
      import:                 @import,
      row_number:             row_number,
      health_number:          health_number,
      health_number_province: health_number_province,
      failure_reason:         reason
    )
  end

  # Maps a CSV row to patient column names.
  # Handles date parsing safely — stores nil if the date is unparseable.
  def patient_attributes(row)
    {
      first_name:           row[:first_name]&.strip,
      last_name:            row[:last_name]&.strip,
      middle_name:          row[:middle_name]&.strip,
      sex:                  row[:sex]&.strip,
      phone_number:         row[:phone_number]&.strip,
      email:                row[:email]&.strip,
      address_line_1:       row[:address_line_1]&.strip,
      address_line_2:       row[:address_line_2]&.strip,
      address_city:         row[:address_city]&.strip,
      address_province:     row[:address_province]&.strip,
      address_postal_code:  row[:address_postal_code]&.strip,
      date_of_birth:        parse_date(row[:date_of_birth])
    }
  end

  # Attempts to parse a date string.
  # Returns nil instead of crashing if the format is unrecognised.
  def parse_date(value)
    return nil if value.blank?
    Date.parse(value.strip)
  rescue ArgumentError
    nil
  end
end