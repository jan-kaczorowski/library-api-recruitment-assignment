class Book < ApplicationRecord
  has_many :book_copies, dependent: :restrict_with_exception

  validates :title, presence: true
  validates :author, presence: true
end