class AhoyRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :ahoy, reading: :ahoy } if ENV["AHOY_DB_URL"].present?
end
