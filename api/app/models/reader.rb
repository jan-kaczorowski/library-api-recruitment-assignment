class Reader < ApplicationRecord
  CARD_RANGE = (100_000..999_999).freeze

  has_many :loans, dependent: :restrict_with_exception
  has_many :book_copies, through: :loans

  before_validation :normalize_email
  before_validation :issue_card_number, on: :create

  validates :full_name, presence: true
  validates :card_number,
            presence: true,
            numericality: { only_integer: true,
                            greater_than_or_equal_to: CARD_RANGE.begin,
                            less_than_or_equal_to: CARD_RANGE.end
                        },
            uniqueness: true
  validates :email, presence: true, uniqueness: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email
  end

  def issue_card_number
    return if card_number.present?

    # Try random unique numbers first to avoid contention; fall back to next after current max.
    10.times do
      candidate = rand(CARD_RANGE)
      unless self.class.exists?(card_number: candidate)
        self.card_number = candidate
        return
      end
    end

    next_after_max = (self.class.maximum(:card_number) || (CARD_RANGE.begin - 1)) + 1
    if CARD_RANGE.cover?(next_after_max)
      self.card_number = next_after_max
    else
      errors.add(:card_number, "pool exhausted")
    end
  end
end