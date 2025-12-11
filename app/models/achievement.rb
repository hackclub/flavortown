# frozen_string_literal: true

Achievement = Data.define(:slug, :name, :description, :icon, :earned_check, :progress) do
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  def initialize(slug:, name:, description:, icon:, earned_check:, progress: nil)
    super(slug:, name:, description:, icon:, earned_check:, progress:)
  end

  ALL = [
    new(
      slug: :first_login,
      name: "Welcome!",
      description: "Log into Flavortown for the first time",
      icon: "user",
      earned_check: ->(user) { user.persisted? }
    ),
    new(
      slug: :identity_verified,
      name: "Verified",
      description: "Verify your identity",
      icon: "checked",
      earned_check: ->(user) { user.identity_verified? }
    ),
    new(
      slug: :hackatime_connected,
      name: "Time Tracker",
      description: "Connect your Hackatime account",
      icon: "time",
      earned_check: ->(user) { user.has_hackatime? }
    ),
    new(
      slug: :first_project,
      name: "Chef",
      description: "Create your first project",
      icon: "fork_spoon_fill",
      earned_check: ->(user) { user.projects.exists? }
    ),
    new(
      slug: :first_devlog,
      name: "Storyteller",
      description: "Post your first devlog",
      icon: "edit",
      earned_check: ->(user) { user.projects.joins(:posts).exists?(posts: { postable_type: "PostDevlog" }) }
    ),
    new(
      slug: :first_comment,
      name: "Conversationalist",
      description: "Leave your first comment",
      icon: "mail",
      earned_check: ->(user) { user.has_commented? }
    ),
    new(
      slug: :first_like,
      name: "Appreciator",
      description: "Like something for the first time",
      icon: "star_fill",
      earned_check: ->(user) { user.likes.exists? }
    ),
    new(
      slug: :first_order,
      name: "Shopper",
      description: "Place your first shop order",
      icon: "shopping_cart_1_fill",
      earned_check: ->(user) { user.shop_orders.exists? }
    ),
    new(
      slug: :five_projects,
      name: "Prolific",
      description: "Create 5 projects",
      icon: "square_fill",
      earned_check: ->(user) { user.projects.count >= 5 },
      progress: ->(user) { { current: user.projects.count, target: 5 } }
    ),
    new(
      slug: :ten_devlogs,
      name: "Dedicated",
      description: "Post 10 devlogs",
      icon: "fire",
      earned_check: ->(user) { Post.joins(:project).where(projects: { id: user.project_ids }, postable_type: "PostDevlog").count >= 10 },
      progress: ->(user) { { current: Post.joins(:project).where(projects: { id: user.project_ids }, postable_type: "PostDevlog").count, target: 10 } }
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

  def earned_by?(user) = earned_check.call(user)

  def progress_for(user)
    return nil unless progress

    progress.call(user)
  end

  def has_progress? = progress.present?
end
