class LoansController < ApplicationController
  # GET /api/loans?open=true
  def index
    loans = Loan.includes(:reader, book_copy: :book).order(borrowed_at: :desc)
    loans = loans.open if params[:open] == "true"

    render json: LoanWithCopyResource.new(loans).serialize
  end

  # POST /api/book_copies/:book_copy_id/loans
  # Body: { reader_id } or { card_number }
  def create
    copy = BookCopy.where(archived_at: nil).find(params[:book_copy_id])
    return render_conflict("Book copy is already borrowed") if copy.open_loan

    loan = copy.borrow!(find_reader)

    render json: LoanWithCopyResource.new(loan).serialize, status: :created
  rescue ActiveRecord::RecordNotUnique
    # Lost a race with a concurrent borrow (idx_loans_one_open_per_copy)
    render_conflict("Book copy is already borrowed")
  end

  # PUT /api/loans/:id/return
  def return_book
    loan = Loan.find(params[:id])
    return render_conflict("Loan is already returned") if loan.returned_at

    loan.return!
    render json: LoanWithCopyResource.new(loan).serialize
  end
end
