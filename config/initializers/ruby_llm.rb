RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", Rails.application.credentials.dig(:openai_api_key))
  # config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", Rails.application.credentials.dig(:anthropic_api_key))
  config.use_new_acts_as = true
end
