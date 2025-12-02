class User::TutorialStep < Data.define(:slug, :name, :description, :icon, :link)
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  include Rails.application.routes.url_helpers

  def self.all = [
    new(:first_login, "First login", "log into the platform for the first time!", "user", "/"),
    new(:post_devlog, "Post a devlog", "dev your log!", "user", "/")
  ].freeze

  def self.slugged = all.index_by(&:slug).freeze

  def self.all_slugs = slugged.keys

  def self.find(slug) = slugged.fetch slug

  def to_param = slug

  def persisted? = true
end
