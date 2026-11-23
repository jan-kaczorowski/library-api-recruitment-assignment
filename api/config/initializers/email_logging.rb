# Log every outgoing email payload (requirement: no real emails are sent)
class EmailLogger
  def self.delivered_email(message)
    Rails.logger.info(<<~LOG)
      [EMAIL] to=#{message.to.join(", ")} subject=#{message.subject.inspect}
      #{(message.text_part || message).body.decoded.strip}
    LOG
  end
end

ActionMailer::Base.register_observer(EmailLogger)
