# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq-status'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS'], password: ENV['REDIS_PASSWORD'] }
  config.client_middleware do |chain|
    # accepts :expiration (optional)
    chain.add Sidekiq::Status::ClientMiddleware, expiration: 30.minutes # default
  end
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS'], password: ENV['REDIS_PASSWORD'] }
  config.server_middleware do |chain|
    # accepts :expiration (optional)
    chain.add Sidekiq::Status::ServerMiddleware, expiration: 30.minutes # default
  end
  config.client_middleware do |chain|
    # accepts :expiration (optional)
    chain.add Sidekiq::Status::ClientMiddleware, expiration: 30.minutes # default
  end
end
