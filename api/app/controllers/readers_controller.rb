class ReadersController < ApplicationController
  # GET /api/readers
  def index
    render json: ReaderResource.new(Reader.order(:full_name)).serialize
  end

  # POST /api/readers
  # Body: { full_name, email } (card_number is optional; issued automatically when omitted)
  def create
    reader = Reader.create!(params.permit(:full_name, :email, :card_number))
    render json: ReaderResource.new(reader).serialize, status: :created
  end
end
