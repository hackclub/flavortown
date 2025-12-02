class User::TutorialStep < Data.define(:slug, :name, :description, :icon, :link)
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  include Rails.application.routes.url_helpers

  ALL = [
    new(:first_login, "First login", "log into the platform for the first time!", "user", "/"),
    new(:post_devlog, "Post a devlog", "dev your log!", "user", "/")
  ].freeze

  SLUGGED = ALL.index_by(&:slug).freeze
  ALL_SLUGS = SLUGGED.keys.freeze

  class << self
    def all = ALL
    def slugged = SLUGGED
    def all_slugs = ALL_SLUGS
    def find(slug) = SLUGGED.fetch slug

    # console affordance - don't let me catch you using this in application code
    alias_method :[], :find
  end

  def to_param = slug

  def persisted? = true
end
