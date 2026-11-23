class LoanWithCopyResource < LoanResource
  one :book_copy, resource: BookCopySummaryResource
end
