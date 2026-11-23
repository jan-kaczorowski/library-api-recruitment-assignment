class BookCopy < ApplicationRecord
  belongs_to :book
  has_many :loans, dependent: :restrict_with_exception
  has_one :open_loan, -> { where(returned_at: nil) }, class_name: "Loan"

  def borrow!(reader, at: Time.current)
    loans.create!(reader: reader, borrowed_at: at, due_on: (at + Loan::PERIOD).to_date)
  end

  # Assigned by the book_copies_serial_number_seq default when not provided
  validates :serial_number, numericality: { only_integer: true,
                                            greater_than_or_equal_to: 100_000,
                                            less_than_or_equal_to: 999_999
                            },
                            allow_nil: true
  validates :serial_number, uniqueness: true, allow_nil: true
end
