# frozen_string_literal: true

Achievement = Data.define(:slug, :name, :description, :icon, :earned?) do
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  ALL = [
    new(
      slug: :first_login,
      name: "Welcome!",
      description: "Log into Flavortown for the first time",
      icon: "user",
      earned?: ->(user) { user.persisted? }
    ),
    new(
      slug: :identity_verified,
      name: "Verified",
      description: "Verify your identity",
      icon: "check",
      earned?: ->(user) { user.identity_verified? }
    ),
    new(
      slug: :hackatime_connected,
      name: "Time Tracker",
      description: "Connect your Hackatime account",
      icon: "time",
      earned?: ->(user) { user.has_hackatime? }
    ),
    new(
      slug: :first_project,
      name: "Chef",
      description: "Create your first project",
      icon: "fork_spoon_fill",
      earned?: ->(user) { user.projects.exists? }
    ),
    new(
      slug: :first_devlog,
      name: "Storyteller",
      description: "Post your first devlog",
      icon: "edit",
      earned?: ->(user) { user.projects.joins(:posts).exists?(posts: { postable_type: "PostDevlog" }) }
    ),
    new(
      slug: :first_comment,
      name: "Conversationalist",
      description: "Leave your first comment",
      icon: "chat",
      earned?: ->(user) { user.has_commented? }
    ),
    new(
      slug: :first_like,
      name: "Appreciator",
      description: "Like something for the first time",
      icon: "heart",
      earned?: ->(user) { user.likes.exists? }
    ),
    new(
      slug: :first_order,
      name: "Shopper",
      description: "Place your first shop order",
      icon: "cart",
      earned?: ->(user) { user.shop_orders.exists? }
    ),
    new(
      slug: :five_projects,
      name: "Prolific",
      description: "Create 5 projects",
      icon: "star",
      earned?: ->(user) { user.projects.count >= 5 }
    ),
    new(
      slug: :ten_devlogs,
      name: "Dedicated",
      description: "Post 10 devlogs",
      icon: "fire",
      earned?: ->(user) { Post.joins(:project).where(projects: { id: user.project_ids }, postable_type: "PostDevlog").count >= 10 }
    )
  ].freeze

  SLUGGED = ALL.index_by(&:slug).freeze
  ALL_SLUGS = SLUGGED.keys.freeze

  class << self
    def all = ALL

    def slugged = SLUGGED

    def all_slugs = ALL_SLUGS

    def find(slug) = SLUGGED.fetch(slug.to_sym)

    alias_method :[], :find
  end

  def to_param = slug

  def persisted? = true

  def earned_by?(user)
    earned?.call(user)
  end
end
