# frozen_string_literal: true

Achievement = Data.define(:slug, :name, :description, :icon, :earned_check, :progress, :visibility, :secret_hint, :excluded_from_count, :cookie_reward) do
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  VISIBILITIES = %i[visible secret hidden].freeze

  def initialize(slug:, name:, description:, icon:, earned_check:, progress: nil, visibility: :visible, secret_hint: nil, excluded_from_count: false, cookie_reward: 0)
    super(slug:, name:, description:, icon:, earned_check:, progress:, visibility:, secret_hint:, excluded_from_count:, cookie_reward:)
  end

  ALL = [
    new(
      slug: :first_login,
      name: "Anyone Can Cook!",
      description: "welcome to the kitchen, chef",
      icon: "chepheus",
      earned_check: ->(user) { user.persisted? }
    ),
    new(
      slug: :identity_verified,
      name: "Very Fried",
      description: "prove you belong in this kitchen!",
      icon: "verified",
      earned_check: ->(user) { user.identity_verified? },
      cookie_reward: 5
    ),
    new(
      slug: :first_project,
      name: "Home Cookin'",
      description: "fire up the stove and start your first dish",
      icon: "fork_spoon_fill",
      earned_check: ->(user) { user.projects.exists? },
      cookie_reward: 3
    ),
    new(
      slug: :first_devlog,
      name: "Recipe Notes",
      description: "jot down your cooking process",
      icon: "edit",
      earned_check: ->(user) { user.projects.joins(:posts).exists?(posts: { postable_type: "Post::Devlog" }) },
      cookie_reward: 2
    ),
    new(
      slug: :first_comment,
      name: "Yapper",
      description: "awawawawawawawa",
      icon: "rac_yap",
      earned_check: ->(user) { user.has_commented? }
    ),
    new(
      slug: :first_order,
      name: "Off the Menu",
      icon: "shopping_cart_1_fill",
      description: "treat yourself to something from the shop",
      earned_check: ->(user) { user.shop_orders.joins(:shop_item).where.not(shop_item: { type: "ShopItem::FreeStickers" }).exists? }
    ),
    new(
      slug: :five_orders,
      name: "Regular Customer",
      icon: "shopping",
      description: "5 orders in - the kitchen knows your name now",
      earned_check: ->(user) { user.shop_orders.real.worth_counting.count >= 5 },
      progress: ->(user) { { current: user.shop_orders.real.worth_counting.count, target: 5 } }
    ),
    new(
      slug: :ten_orders,
      name: "VIP Diner",
      description: "10 orders?! we're naming a dish after you",
      icon: "shopping_cart_1_fill",
      earned_check: ->(user) { user.shop_orders.real.worth_counting.count >= 10 },
      progress: ->(user) { { current: user.shop_orders.real.worth_counting.count, target: 10 } }
    ),
    new(
      slug: :flavortown_helper,
      name: "Helping Hand",
      description: "shared your wisdom in #flavortown-help, or seeked thy wisdom",
      icon: "help",
      earned_check: ->(user) { SlackChannelService.user_has_posted_in?(user, :flavortown_help) }
    ),
    new(
      slug: :flavortown_chatter,
      name: "Kitchen slacker",
      description: "joined the conversation in #flavortown",
      icon: "slack",
      earned_check: ->(user) { SlackChannelService.user_has_posted_in?(user, :flavortown) }
    ),
    new(
      slug: :flavortown_introduced,
      name: "Hello, Kitchen!",
      description: "introduced yourself in #flavortown-introduction",
      icon: "user",
      earned_check: ->(user) { SlackChannelService.user_has_posted_in?(user, :flavortown_introduction) },
      cookie_reward: 2
    ),
    new(
      slug: :five_projects,
      name: "Line Cook",
      description: "5 dishes cooking at once? mise en place!",
      icon: "square_fill",
      earned_check: ->(user) { user.projects.count >= 5 },
      progress: ->(user) { { current: user.projects.count, target: 5 } },
      cookie_reward: 10
    ),
    new(
      slug: :first_ship,
      name: "Order Up!",
      description: "ship your first project to the world",
      icon: "ship",
      earned_check: ->(user) { user.projects.where(ship_status: "submitted").exists? },
      cookie_reward: 3
    ),
    new(
      slug: :ship_certified,
      name: "Michelin Star",
      description: "your dish has been certified by the critics",
      icon: "trophy",
      earned_check: ->(user) { Post::ShipEvent.joins(:post).where(posts: { user_id: user.id }, certification_status: "approved").exists? },
      cookie_reward: 3
    ),
    new(
      slug: :ten_devlogs,
      name: "Cookbook Author",
      description: "10 recipes documented - publish that cookbook!",
      icon: "fire",
      earned_check: ->(user) { Post.joins(:project).where(projects: { id: user.project_ids }, postable_type: "Post::Devlog").count >= 10 },
      progress: ->(user) { { current: Post.joins(:project).where(projects: { id: user.project_ids }, postable_type: "Post::Devlog").count, target: 10 } },
      cookie_reward: 15,
      visibility: :secret
    ),
    new(
      slug: :scrapbook_devlog,
      name: "Scrapbook usage?!",
      description: "Used scrapbook in a devlog",
      icon: "slack",
      earned_check: ->(user) { Post::Devlog.joins(:post).where(posts: { project_id: user.project_ids }).where.not(scrapbook_url: nil).exists? },
      visibility: :secret
    ),
    new(
      slug: :cooking,
      name: "Cooking",
      description: "Cooked so hard you ended up making a fire project that made our staff very happy!",
      icon: "fire",
      earned_check: ->(user) { user.projects.fire.exists? },
      cookie_reward: 5,
      visibility: :secret
    ),
    new(
      slug: :extension_2_users,
      name: "Free Sample!",
      description: "Built an extension that 2+ people are using!",
      icon: "fork_spoon_fill",
      earned_check: ->(user) {
        ExtensionUsage.max_weekly_users_for(user.project_ids) >= 2
      },
      progress: ->(user) { { current: ExtensionUsage.max_weekly_users_for(user.project_ids), target: 2 } },
      cookie_reward: 10
    )
  ].freeze

  SECRET = (Secrets.available? ? SecretAchievements::DEFINITIONS.map { |d| new(**d) } : []).freeze

  ALL_WITH_SECRETS = (ALL + SECRET).freeze
  SLUGGED = ALL_WITH_SECRETS.index_by(&:slug).freeze
  ALL_SLUGS = SLUGGED.keys.freeze

  class << self
    def all = ALL_WITH_SECRETS

    def slugged = SLUGGED

    def all_slugs = ALL_SLUGS

    def find(slug) = SLUGGED.fetch(slug.to_sym)

    alias_method :[], :find

    def countable
      ALL_WITH_SECRETS.reject(&:excluded_from_count)
    end

    def countable_for_user(user)
      countable.select { |a| a.shown_to?(user, earned: a.earned_by?(user)) }
    end
  end

  def to_param = slug

  def persisted? = true

  def visible? = visibility == :visible
  def secret? = visibility == :secret
  def hidden? = visibility == :hidden

  def shown_to?(user, earned:)
    return true if earned
    return true if visible?
    return true if secret?

    false
  end

  def earned_by?(user) = earned_check.call(user)

  def progress_for(user)
    return nil unless progress

    progress.call(user)
  end

  def has_progress? = progress.present?

  def has_cookie_reward? = cookie_reward.positive?

  SECRET_DESCRIPTIONS = [
    "the secret ingredient is... secret",
    "something's cooking... 👀",
    "this recipe is under wraps",
    "only the head chef knows this one",
    "a mystery dish awaits...",
    "keep stirring the pot to find out!",
    "classified kitchen intel 🤫",
    "shhh... it's marinating"
  ].freeze

  def display_name(earned:)
    return name if earned || visible?

    secret? ? "???" : name
  end

  def display_description(earned:)
    return description if earned || visible?

    secret_hint || SECRET_DESCRIPTIONS.sample
  end

  def show_progress?(earned:)
    return false if earned
    return false unless has_progress?
    return false if hidden?

    true
  end
end
