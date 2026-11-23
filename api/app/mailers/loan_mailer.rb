class LoanMailer < ApplicationMailer
  before_action { @loan = params[:loan] }
  before_action { @reader = @loan.reader }
  before_action { @book = @loan.book_copy.book }

  # 3 days before the due date
  def due_soon
    mail to: @reader.email, subject: "Reminder: \"#{@book.title}\" is due on #{@loan.due_on}"
  end

  # On the due date
  def due_today
    mail to: @reader.email, subject: "\"#{@book.title}\" is due today"
  end
end
