require "rails_helper"

RSpec.describe LoanRemindersJob, type: :job do
  let(:today) { Date.new(2026, 11, 23) }

  def loan_due(due_on, **attrs)
    create_loan(copy: create_copy, borrowed_at: (due_on - 30).in_time_zone, **attrs).tap do |loan|
      loan.update!(due_on: due_on)
    end
  end

  around { |example| travel_to(today.in_time_zone.change(hour: 8)) { example.run } }

  it "sends the 3-day reminder for loans due in 3 days" do
    loan = loan_due(today + 3)

    expect { described_class.perform_now }
      .to have_enqueued_mail(LoanMailer, :due_soon).with(params: { loan: loan }, args: [])

    expect(loan.reload.three_day_reminder_sent_at).to be_present
  end

  it "sends the due-date reminder for loans due today" do
    loan = loan_due(today)

    expect { described_class.perform_now }
      .to have_enqueued_mail(LoanMailer, :due_today).with(params: { loan: loan }, args: [])

    expect(loan.reload.due_day_reminder_sent_at).to be_present
  end

  it "still sends the 3-day reminder if a daily run was missed" do
    loan = loan_due(today + 2)

    expect { described_class.perform_now }
      .to have_enqueued_mail(LoanMailer, :due_soon).with(params: { loan: loan }, args: [])
  end

  it "sends each reminder only once" do
    loan_due(today + 3)
    loan_due(today)
    described_class.perform_now

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "skips returned loans" do
    loan_due(today, returned_at: 1.day.ago)
    loan_due(today + 3, returned_at: 1.day.ago)

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "skips loans not yet due for a reminder and overdue loans" do
    loan_due(today + 4)
    loan_due(today - 1)

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end
end
