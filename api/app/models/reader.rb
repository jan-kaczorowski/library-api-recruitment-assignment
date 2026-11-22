class Reader < ApplicationRecord
  has_many :loans, dependent: :restrict_with_exception
  has_many :book_copies, through: :loans

  before_validation :normalize_email

  validates :full_name, presence: true
  validates :card_number,
            presence: true,
            numericality: { only_integer: true, greater_than_or_equal_to: 100_000, less_than_or_equal_to: 999_999 },
            uniqueness: true
  validates :email, presence: true, uniqueness: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email
  end
end