require "rails_helper"

RSpec.describe LoanMailer, type: :mailer do
  let(:reader) { create_reader(full_name: "Anna Nowak", email: "anna@example.pl") }
  let(:copy) { create_copy(book: create_book(title: "Lalka", author: "Bolesław Prus")) }
  let(:loan) { create_loan(copy: copy, reader: reader, borrowed_at: Time.zone.local(2026, 10, 24, 12)) }

  describe "#due_soon" do
    subject(:mail) { described_class.with(loan: loan).due_soon }

    it "reminds the reader of the due date" do
      expect(mail.to).to eq([ "anna@example.pl" ])
      expect(mail.subject).to eq("Reminder: \"Lalka\" is due on 2026-11-23")
      expect(mail.text_part.body.decoded).to include("Anna Nowak", "Lalka", "Bolesław Prus",
                                                     copy.serial_number.to_s, "2026-11-23")
    end
  end

  describe "#due_today" do
    subject(:mail) { described_class.with(loan: loan).due_today }

    it "tells the reader the book is due today" do
      expect(mail.to).to eq([ "anna@example.pl" ])
      expect(mail.subject).to eq("\"Lalka\" is due today")
      expect(mail.html_part.body.decoded).to include("Anna Nowak", "Lalka", "today")
    end
  end
end
