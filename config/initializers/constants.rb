Rails.application.config.billy_url = (Rails.application.credentials.dig(:constants, :billy_url) || ENV["BILLY_URL"]) || "https://billy/"
Rails.application.config.joe_url = (Rails.application.credentials.dig(:constants, :joe_url) || ENV["JOE_URL"]) || "https://joe/"
