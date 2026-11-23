class BookCopyResource
  include Alba::Resource

  attributes :id, :serial_number, :book_id

  attribute(:title) { |copy| copy.book.title }
  attribute(:author) { |copy| copy.book.author }
  attribute(:status) { |copy| copy.open_loan ? "borrowed" : "available" }

  one :open_loan, key: :current_loan, resource: LoanResource
end
