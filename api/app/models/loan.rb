class Loan < ApplicationRecord
  belongs_to :book_copy
  belongs_to :reader

  scope :open, -> { where(returned_at: nil) }

  validates :borrowed_at, presence: true
  validates :due_on, presence: true
  validate :return_after_borrow

  # Application-level safety net; DB enforces this with a partial unique index
  validates :book_copy_id, uniqueness: { conditions: -> { where(returned_at: nil) }, message: "already has an open loan" }, if: -> { returned_at.nil? }

  private

  def return_after_borrow
    return if returned_at.nil? || borrowed_at.nil?
    errors.add(:returned_at, "must be after borrowed_at") if returned_at < borrowed_at
  end
end