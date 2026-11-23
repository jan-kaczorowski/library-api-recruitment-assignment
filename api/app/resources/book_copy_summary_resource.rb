# Compact copy representation embedded in loan responses
class BookCopySummaryResource
  include Alba::Resource

  attributes :id, :serial_number

  attribute(:title) { |copy| copy.book.title }
  attribute(:author) { |copy| copy.book.author }
end
