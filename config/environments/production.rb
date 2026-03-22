require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Serve static files (Render doesn't use nginx in front)
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.assets.compile = false

  config.active_storage.service = :local

  # Force SSL on Render (handles TLS termination)
  config.force_ssl = true
  config.assume_ssl = true

  # Logging
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }
  config.log_tags = [ :request_id ]
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Use async queue adapter (no separate worker needed on free tier)
  config.active_job.queue_adapter = :async

  config.action_mailer.perform_caching = false
  config.i18n.fallbacks = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  # Allow Render hosts
  config.hosts.clear

  # Allow Action Cable connections
  config.action_cable.disable_request_forgery_protection = true
end
