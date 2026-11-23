class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: e.message }, status: :not_found
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { errors: e.record.errors.to_hash(true) }, status: :unprocessable_content
  end

  rescue_from ActiveRecord::RecordNotUnique do
    render json: { error: "Record conflicts with an existing one" }, status: :conflict
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end

  private

  def render_conflict(message)
    render json: { error: message }, status: :conflict
  end

  # Borrowing reader from { reader_id } or { card_number }
  def find_reader
    if params[:reader_id].present?
      Reader.find(params[:reader_id])
    else
      Reader.find_by!(card_number: params.require(:card_number))
    end
  end
end
