# Book copy with its full borrowing history, newest first
class BookCopyDetailResource < BookCopyResource
  many :loans,
       proc { |loans| loans.includes(:reader).order(borrowed_at: :desc) },
       resource: LoanResource
end
