# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

retry_options = {
  max: 2,
  interval: 0.05,
  interval_randomness: 0.5,
  backoff_factor: 2
}

OpenRouter.configure do |config|
  config.site_name = 'HostedGPT'
  config.site_url = 'https://github.com/allyourbot/hostedgpt'
  config.faraday do |f|
    f.request :retry, retry_options
    f.response :logger, ::Logger.new($stdout), { headers: true, bodies: true, errors: true } do |logger|
      logger.filter(/(Bearer) (\S+)/, '\1[REDACTED]')
    end
  end
end

