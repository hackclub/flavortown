class User
  TutorialStep = Data.define(:slug, :name, :description, :icon, :link, :deps, :verb) do
    include ActiveModel::Conversion
    extend ActiveModel::Naming

    def initialize(params = {})
      params[:deps] ||= nil
      params[:verb] ||= :get
      super(**params)
    end

    # N.B.: this is not a proper graph, so be careful with your preconditions!
    # revoking a tutorial step (i.e. on delete) does not propagate up through dependency chains.
    Dep = Data.define(:slug, :hint) do
      def satisfied?(completed_steps) = completed_steps.include? slug
    end

    ALL = [
      new(:first_login, "First login", "log into the platform for the first time!", "user", "/"),
      new(slug: :identity_verified,
          name: "Confirm your age",
          description: "you must be under this tall to ride!",
          icon: "user",
          link: "https://auth.hackclub.com/verifications/new"),
      new(slug: :setup_hackatime,
          name: "Setup hackatime",
          description: "Start tracking your time",
          icon: "time",
          link: "/auth/hackatime",
          verb: :post),
      new(slug: :create_project,
          name: "Create your first project",
          description: "what are you cooking?",
          icon: "fork_spoon_fill",
          link: ->(_) { new_project_path },
          deps: [
            Dep[:setup_hackatime, "you need to setup hackatime first!"]
          ]),
      new(slug: :post_devlog,
          name: "Post a devlog",
          description: "dev your log!",
          icon: "edit",
          link: ->(_) { new_project_devlog_path(current_user.projects.first) },
          deps: [
            Dep[:create_project, "you need to create a project first!"]
          ]),
      new(slug: :free_stickers,
          name: "Get your stickers!",
          description: "get your stickers!",
          icon: "trash-bin",
          link: ->(_) { shop_order_path(shop_item_id: ShopItem::FreeStickers.first&.id) },
          deps: [
            Dep[:post_devlog, "you need to dev on your log first!"],
            Dep[:identity_verified, "you need to verify your identity!"]
          ])
    ].freeze

    SLUGGED = ALL.index_by(&:slug).freeze
    ALL_SLUGS = SLUGGED.keys.freeze

    class << self
      def all = ALL

      def slugged = SLUGGED

      def all_slugs = ALL_SLUGS

      def find(slug) = SLUGGED.fetch slug.to_sym

      # console affordance - don't let me catch you using this in application code
      alias_method :[], :find
    end

    def deps_satisfied?(completed_steps)
      return true unless deps&.any?

      deps.all? { |dep| dep.satisfied?(completed_steps) }
    end

    def to_param = slug

    def persisted? = true
  end
end
