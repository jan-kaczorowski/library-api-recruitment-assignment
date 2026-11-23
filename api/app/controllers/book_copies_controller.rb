class BookCopiesController < ApplicationController
  # GET /api/book_copies
  def index
    copies = active_copies.includes(:book, open_loan: :reader).order(:serial_number)
    render json: BookCopyResource.new(copies).serialize
  end

  # GET /api/book_copies/:id
  def show
    copy = active_copies.includes(:book, open_loan: :reader).find(params[:id])
    render json: BookCopyDetailResource.new(copy).serialize
  end

  # POST /api/book_copies
  # Body: { serial_number, book_id } or { serial_number, title, author }
  def create
    copy = find_or_create_book.book_copies.create!(serial_number: params[:serial_number])
    render json: BookCopyResource.new(copy).serialize, status: :created
  end

  # PATCH /api/book_copies/:id
  # Body: { status: "borrowed", card_number | reader_id } or { status: "available" }
  # Status-style alternative to POST /book_copies/:id/loans and PUT /loans/:id/return.
  def update
    copy = active_copies.find(params[:id])

    case params.require(:status)
    when "borrowed"
      return render_conflict("Book copy is already borrowed") if copy.open_loan
      copy.borrow!(find_reader)
    when "available"
      return render_conflict("Book copy is already available") unless copy.open_loan
      copy.open_loan.return!
    else
      return render json: { errors: { status: [ "must be borrowed or available" ] } },
                    status: :unprocessable_content
    end

    render json: BookCopyResource.new(copy.reload).serialize
  end

  # DELETE /api/book_copies/:id
  # Copies with loan history are archived so the history is kept.
  def destroy
    copy = active_copies.find(params[:id])
    return render_conflict("Book copy is currently borrowed") if copy.open_loan

    if copy.loans.exists?
      copy.update!(archived_at: Time.current)
    else
      copy.destroy!
    end

    head :no_content
  end

  private

  def active_copies
    BookCopy.where(archived_at: nil)
  end

  def find_or_create_book
    return Book.find(params[:book_id]) if params[:book_id].present?

    Book.find_or_create_by!(title: params.require(:title), author: params.require(:author))
  end
end
