# frozen_string_literal: true

# Conditionally load secret configurations from the secrets submodule.
# This submodule is only cloned in production, not in development.
#
# Structure:
#   secrets/
#     initializers/  -> loaded at boot (like config/initializers)
#     app/
#       models/      -> autoloaded (namespaced under Secrets::)
#       services/    -> autoloaded (namespaced under Secrets::)
#     data/          -> YAML/JSON accessible via Secrets.data("filename")
#
# Usage:
#   Secrets.available?              # => true/false
#   Secrets.data("special_items")   # => loads secrets/data/special_items.yml
#   Secrets::MySecretModel          # => autoloaded from secrets/app/models/

secrets_path = Rails.root.join("secrets")

module Secrets
  class << self
    def available?
      root.exist? && root.directory? && root.join("app").exist?
    end

    def root
      Rails.root.join("secrets")
    end

    def data(name)
      return nil unless available?

      file = data_path.join("#{name}.yml")
      return nil unless file.exist?

      @data_cache ||= {}
      @data_cache[name] ||= YAML.load_file(file, permitted_classes: [ Symbol, Date, Time ])
    end

    def data_path
      root.join("data")
    end
  end
end

if secrets_path.exist? && secrets_path.directory?
  # Load initializers from secrets/initializers/
  secrets_initializers = secrets_path.join("initializers")
  if secrets_initializers.exist?
    Dir.glob(secrets_initializers.join("**/*.rb")).sort.each do |file|
      require file
    end
  end

  Rails.logger.info "[SecretsLoader] Loaded secrets from #{secrets_path}" if defined?(Rails.logger) && Rails.logger
end
