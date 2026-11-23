module ApiHelpers
  def json
    response.parsed_body
  end

  def create_book(title: "Lalka", author: "Bolesław Prus")
    Book.create!(title: title, author: author)
  end

  def create_copy(book: create_book, serial_number: nil)
    book.book_copies.create!(serial_number: serial_number)
  end

  def create_reader(full_name: "Jan Kowalski", email: "jan#{SecureRandom.hex(4)}@example.com")
    Reader.create!(full_name: full_name, email: email)
  end

  def create_loan(copy:, reader: create_reader, borrowed_at: Time.current, returned_at: nil)
    copy.loans.create!(reader: reader, borrowed_at: borrowed_at,
                       due_on: (borrowed_at + 30.days).to_date, returned_at: returned_at)
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
  config.include ApiHelpers, type: :job
  config.include ApiHelpers, type: :mailer
  config.include ActiveSupport::Testing::TimeHelpers
end
