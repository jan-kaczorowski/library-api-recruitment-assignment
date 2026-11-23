require "rails_helper"

RSpec.describe "Loans API", type: :request do
  describe "GET /api/loans" do
    it "lists all loans with reader and copy" do
      copy = create_copy
      returned = create_loan(copy: copy, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
      open_loan = create_loan(copy: copy)

      get "/api/loans"

      expect(response).to have_http_status(:ok)
      expect(json.map { |l| l["id"] }).to eq([ open_loan.id, returned.id ])
      expect(json.first["book_copy"]).to include("serial_number" => copy.serial_number, "title" => "Lalka")
      expect(json.first["reader"]).to include("card_number" => open_loan.reader.card_number)
    end

    it "filters open loans with open=true" do
      copy = create_copy
      create_loan(copy: copy, borrowed_at: 10.days.ago, returned_at: 1.day.ago)
      open_loan = create_loan(copy: copy)

      get "/api/loans", params: { open: "true" }

      expect(json.map { |l| l["id"] }).to eq([ open_loan.id ])
    end
  end

  describe "POST /api/book_copies/:book_copy_id/loans" do
    let(:copy) { create_copy }
    let(:reader) { create_reader }

    it "borrows a copy by card number for 30 days" do
      travel_to Time.zone.local(2026, 11, 23, 12, 0, 0) do
        post "/api/book_copies/#{copy.id}/loans", params: { card_number: reader.card_number }, as: :json
      end

      expect(response).to have_http_status(:created)
      expect(json).to include("due_on" => "2026-12-23", "returned_at" => nil)
      expect(json["reader"]).to include("id" => reader.id)
      expect(json["book_copy"]).to include("id" => copy.id)
      expect(copy.reload.open_loan).to be_present
    end

    it "borrows a copy by reader_id" do
      post "/api/book_copies/#{copy.id}/loans", params: { reader_id: reader.id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["reader"]["id"]).to eq(reader.id)
    end

    it "refuses to borrow an already borrowed copy" do
      create_loan(copy: copy)

      expect {
        post "/api/book_copies/#{copy.id}/loans", params: { reader_id: reader.id }, as: :json
      }.not_to change(Loan, :count)

      expect(response).to have_http_status(:conflict)
    end

    it "returns 404 for an archived copy" do
      copy.update!(archived_at: Time.current)

      post "/api/book_copies/#{copy.id}/loans", params: { reader_id: reader.id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for an unknown reader" do
      post "/api/book_copies/#{copy.id}/loans", params: { card_number: 999_999 }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 400 without a reader" do
      post "/api/book_copies/#{copy.id}/loans", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "PUT /api/loans/:id/return" do
    it "returns a borrowed copy" do
      copy = create_copy
      loan = create_loan(copy: copy, borrowed_at: 5.days.ago)

      put "/api/loans/#{loan.id}/return"

      expect(response).to have_http_status(:ok)
      expect(json["returned_at"]).to be_present
      expect(copy.reload.open_loan).to be_nil
    end

    it "refuses to return an already returned loan" do
      loan = create_loan(copy: create_copy, borrowed_at: 5.days.ago, returned_at: 1.day.ago)

      put "/api/loans/#{loan.id}/return"

      expect(response).to have_http_status(:conflict)
    end

    it "returns 404 for an unknown loan" do
      put "/api/loans/0/return"

      expect(response).to have_http_status(:not_found)
    end
  end
end
