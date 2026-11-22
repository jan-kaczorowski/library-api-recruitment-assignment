class BookCopy < ApplicationRecord
  belongs_to :book
  has_many :loans, dependent: :restrict_with_exception
  has_one :open_loan, -> { where(returned_at: nil) }, class_name: "Loan"

  validates :serial_number, presence: true,
                            numericality: { only_integer: true, greater_than_or_equal_to: 100_000, less_than_or_equal_to: 999_999 }
  validates :serial_number, uniqueness: true
end