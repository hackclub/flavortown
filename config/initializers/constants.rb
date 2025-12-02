Rails.application.config.billy_url = (Rails.application.credentials.dig(:constants, :billy_url) || ENV["BILLY_URL"]) || "https://billy/"
Rails.application.config.joe_url = (Rails.application.credentials.dig(:constants, :joe_url) || ENV["JOE_URL"]) || "https://joe/"
Rails.application.config.identity = (Rails.application.credentials.dig(:hack_club, :site) || Rails.application.credentials.dig(:constants, :identity_url) || ENV["IDV_URL"]) || "https://auth.hackclub.com/"
