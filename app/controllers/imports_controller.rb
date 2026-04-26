# app/controllers/imports_controller.rb

class ImportsController < ApplicationController
  def index
  end

  def create
    # Stage 1 — check a file was actually attached
    unless params[:file].present?
      flash[:error] = 'Please select a file to upload.'
      redirect_to root_path and return
    end

    # Stage 2 — check MIME type
    unless valid_csv?(params[:file])
      flash[:error] = 'Invalid file type. Please upload a CSV file.'
      redirect_to root_path and return
    end

    # Hand off to the service — controller's job is done after this line
    @import = PatientImportService.new(params[:file]).call

    redirect_to import_path(@import)

  end

  def show
    @import = Import.find(params[:id])
  end


  private

  def valid_csv?(file)
    file.content_type.in?(['text/csv', 'application/vnd.ms-excel'])
  end
end