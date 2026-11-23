require "rails_helper"

RSpec.describe "Readers API", type: :request do
  describe "GET /api/readers" do
    it "lists readers" do
      reader = create_reader(full_name: "Anna Nowak")

      get "/api/readers"

      expect(response).to have_http_status(:ok)
      expect(json).to contain_exactly(
        "id" => reader.id, "card_number" => reader.card_number,
        "full_name" => "Anna Nowak", "email" => reader.email
      )
    end
  end

  describe "POST /api/readers" do
    it "creates a reader with an auto-issued six-digit card number" do
      post "/api/readers", params: { full_name: "Piotr Zieliński", email: " Piotr@Example.com " }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to include("full_name" => "Piotr Zieliński", "email" => "piotr@example.com")
      expect(json["card_number"]).to be_between(100_000, 999_999)
    end

    it "accepts a given card number" do
      post "/api/readers", params: { full_name: "Jan Kowalski", email: "jan@example.com", card_number: 123_456 }, as: :json

      expect(response).to have_http_status(:created)
      expect(json["card_number"]).to eq(123_456)
    end

    it "rejects a duplicate email" do
      create_reader(email: "jan@example.com")

      post "/api/readers", params: { full_name: "Jan Kowalski", email: "JAN@example.com" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("email")
    end

    it "rejects a duplicate card number" do
      existing = create_reader

      post "/api/readers", params: { full_name: "Jan Kowalski", email: "other@example.com", card_number: existing.card_number }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("card_number")
    end

    it "rejects an invalid email address" do
      post "/api/readers", params: { full_name: "Jan Kowalski", email: "not-an-email" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]["email"]).to include("Email is invalid")
    end

    it "rejects missing name and email" do
      post "/api/readers", params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"].keys).to include("full_name", "email")
    end
  end
end
