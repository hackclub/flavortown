class User
  TutorialStep = Data.define(:slug, :name, :description, :icon, :link, :deps) do
    include ActiveModel::Conversion
    extend ActiveModel::Naming
    include Rails.application.routes.url_helpers

    def initialize(params = {})
      params[:deps] ||= nil
      super(**params)
    end

    # N.B.: this is not a proper graph, so be careful with your preconditions!
    # revoking a tutorial step (i.e. on delete) does not propagate up through dependency chains.
    Dep = Data.define(:slug, :hint) do
      def satisfied?(completed_steps) = completed_steps.include? slug
    end

  ALL = [
    new(:first_login, "First login", "log into the platform for the first time!", "user", "/"),
    new(slug: :post_devlog,
        name: "Post a devlog",
        description: "dev your log!",
        icon: "user",
        link: "/",
        deps: [
          Dep[:create_project, "you need to create a project first!"]
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
