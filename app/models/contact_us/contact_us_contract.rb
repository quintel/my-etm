class ContactUsContract < Dry::Validation::Contract
  params do
    required(:email).filled(:string)
    required(:name).filled(:string)
    required(:message).filled(:string)
  end

  # Validates that the sender is not using our own domain. This is a strangely common
  # occurrence with spammers.
  rule(:email) do
    if !Devise.email_regexp.match?(value)
      key.failure(:invalid_format)
    elsif value.to_s.strip.end_with?("@energytransitionmodel.com")
      key.failure(:disallowed_domain)
    end
  end

  # Validates that the message doesn't contain words frequently used by spammers.
  rule(:message) do
    mess = value.to_s.downcase

    if mess.match?(/\bdomain\b/) || mess.match?(/\brenew\b/) || mess.match?(/\bporn\b/)
      key.failure(:disallowed_content)
    end
  end
end
