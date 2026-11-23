require "rails_helper"

RSpec.describe "Book copies API", type: :request do
  describe "GET /api/book_copies" do
    it "lists copies with availability" do
      available = create_copy
      borrowed = create_copy(book: create_book(title: "Solaris", author: "Stanisław Lem"))
      reader = create_reader
      create_loan(copy: borrowed, reader: reader)

      get "/api/book_copies"

      expect(response).to have_http_status(:ok)
      by_id = json.index_by { |c| c["id"] }
      expect(by_id[available.id]).to include("status" => "available", "current_loan" => nil,
                                             "title" => "Lalka", "author" => "Bolesław Prus")
      expect(by_id[borrowed.id]).to include("status" => "borrowed")
      expect(by_id[borrowed.id]["current_loan"]["reader"]).to include("card_number" => reader.card_number)
    end

    it "excludes archived copies" do
      create_copy.update!(archived_at: Time.current)

      get "/api/book_copies"

      expect(json).to be_empty
    end
  end

  describe "GET /api/book_copies/:id" do
    it "returns the copy with full loan history, newest first" do
      copy = create_copy
      reader = create_reader(full_name: "Anna Nowak")
      old_loan = create_loan(copy: copy, reader: reader, borrowed_at: 40.days.ago, returned_at: 20.days.ago)
      new_loan = create_loan(copy: copy, reader: reader, borrowed_at: 1.day.ago)

      get "/api/book_copies/#{copy.id}"

      expect(response).to have_http_status(:ok)
      expect(json).to include("serial_number" => copy.serial_number, "status" => "borrowed")
      expect(json["loans"].map { |l| l["id"] }).to eq([ new_loan.id, old_loan.id ])
      expect(json["loans"].last).to include("returned_at" => be_present, "due_on" => old_loan.due_on.iso8601)
      expect(json["loans"].last["reader"]).to include("full_name" => "Anna Nowak", "email" => reader.email)
    end

    it "returns 404 for an unknown copy" do
      get "/api/book_copies/0"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/book_copies" do
    it "creates a copy of a new book from title and author" do
      expect {
        post "/api/book_copies", params: { title: "Quo Vadis", author: "Henryk Sienkiewicz" }, as: :json
      }.to change(Book, :count).by(1).and change(BookCopy, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include("title" => "Quo Vadis", "status" => "available")
      expect(json["serial_number"]).to be_between(100_000, 999_999)
    end

    it "reuses an existing book with the same title and author" do
      book = create_book

      expect {
        post "/api/book_copies", params: { title: book.title, author: book.author }, as: :json
      }.not_to change(Book, :count)

      expect(json["book_id"]).to eq(book.id)
    end

    it "adds a copy to an existing book by book_id" do
      book = create_book

      post "/api/book_copies", params: { book_id: book.id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["book_id"]).to eq(book.id)
    end

    it "auto-assigns unique serial numbers" do
      book = create_book

      2.times { post "/api/book_copies", params: { book_id: book.id }, as: :json }

      expect(BookCopy.pluck(:serial_number).uniq.size).to eq(2)
    end

    it "accepts a given serial number" do
      post "/api/book_copies", params: { book_id: create_book.id, serial_number: 654_321 }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["serial_number"]).to eq(654_321)
    end

    it "rejects a duplicate serial number" do
      copy = create_copy

      post "/api/book_copies", params: { book_id: copy.book_id, serial_number: copy.serial_number }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("serial_number")
    end

    it "rejects a serial number that is not six digits" do
      post "/api/book_copies", params: { book_id: create_book.id, serial_number: 42 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 400 without book_id or title/author" do
      post "/api/book_copies", params: { title: "Lalka", author: "" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 for an unknown book_id" do
      post "/api/book_copies", params: { book_id: 0 }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/book_copies/:id" do
    let(:copy) { create_copy }
    let(:reader) { create_reader }

    it "marks a copy as borrowed by card number for 30 days" do
      travel_to Time.zone.local(2026, 11, 23, 12, 0, 0) do
        patch "/api/book_copies/#{copy.id}", params: { status: "borrowed", card_number: reader.card_number }, as: :json
      end

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "borrowed")
      expect(json["current_loan"]).to include("due_on" => "2026-12-23")
      expect(json["current_loan"]["reader"]).to include("id" => reader.id)
    end

    it "marks a copy as borrowed by reader_id" do
      patch "/api/book_copies/#{copy.id}", params: { status: "borrowed", reader_id: reader.id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(copy.reload.open_loan.reader).to eq(reader)
    end

    it "marks a borrowed copy as available" do
      loan = create_loan(copy: copy, reader: reader, borrowed_at: 5.days.ago)

      patch "/api/book_copies/#{copy.id}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "available", "current_loan" => nil)
      expect(loan.reload.returned_at).to be_present
    end

    it "refuses to borrow an already borrowed copy" do
      create_loan(copy: copy)

      expect {
        patch "/api/book_copies/#{copy.id}", params: { status: "borrowed", reader_id: reader.id }, as: :json
      }.not_to change(Loan, :count)

      expect(response).to have_http_status(:conflict)
    end

    it "refuses to mark an available copy as available" do
      patch "/api/book_copies/#{copy.id}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:conflict)
    end

    it "rejects an unknown status" do
      patch "/api/book_copies/#{copy.id}", params: { status: "lost" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 400 without a status" do
      patch "/api/book_copies/#{copy.id}", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when borrowing without a reader" do
      patch "/api/book_copies/#{copy.id}", params: { status: "borrowed" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 for an unknown reader" do
      patch "/api/book_copies/#{copy.id}", params: { status: "borrowed", card_number: 999_999 }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an archived copy" do
      copy.update!(archived_at: Time.current)

      patch "/api/book_copies/#{copy.id}", params: { status: "available" }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/book_copies/:id" do
    it "deletes a copy without loan history" do
      copy = create_copy

      expect { delete "/api/book_copies/#{copy.id}" }.to change(BookCopy, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "archives a copy with loan history" do
      copy = create_copy
      create_loan(copy: copy, borrowed_at: 10.days.ago, returned_at: 1.day.ago)

      expect { delete "/api/book_copies/#{copy.id}" }.not_to change(BookCopy, :count)

      expect(response).to have_http_status(:no_content)
      expect(copy.reload.archived_at).to be_present
    end

    it "refuses to delete a borrowed copy" do
      copy = create_copy
      create_loan(copy: copy)

      delete "/api/book_copies/#{copy.id}"

      expect(response).to have_http_status(:conflict)
      expect(copy.reload.archived_at).to be_nil
    end

    it "returns 404 for an already archived copy" do
      copy = create_copy
      copy.update!(archived_at: Time.current)

      delete "/api/book_copies/#{copy.id}"

      expect(response).to have_http_status(:not_found)
    end
  end
end
