# Runs daily (config/schedule.yml). Each reminder is sent once per loan; the
# *_reminder_sent_at columns make reruns safe.
class LoanRemindersJob < ApplicationJob
  queue_as :default

  def perform(today = Date.current)
    # Range instead of an exact date, so a missed run still sends the reminder later
    send_reminders(:due_soon, :three_day_reminder_sent_at, due_on: (today + 1)..(today + 3))
    send_reminders(:due_today, :due_day_reminder_sent_at, due_on: today)
  end

  private

  def send_reminders(mail, sent_column, due_on:)
    Loan.open.where(due_on: due_on, sent_column => nil).find_each do |loan|
      LoanMailer.with(loan: loan).public_send(mail).deliver_later
      loan.update!(sent_column => Time.current)
    end
  end
end
