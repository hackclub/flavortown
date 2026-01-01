# == Schema Information
#
# Table name: posts
#
#  id            :bigint           not null, primary key
#  postable_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  postable_id   :bigint
#  project_id    :bigint           not null
#  user_id       :bigint
#
# Indexes
#
#  index_posts_on_postable_type_and_postable_id  (postable_type,postable_id) UNIQUE
#  index_posts_on_project_id                     (project_id)
#  index_posts_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class Post < ApplicationRecord
    # Eager load all Post::* classes so Postable.types is populated
    Dir[Rails.root.join("app/models/post/*.rb")].each { |f| require_dependency f }

    belongs_to :project, touch: true
    # optional because it can be a system post – achievements, milestones, well-done/magic happening, etc –
    # integeration – git remotes – or a user post
    belongs_to :user, optional: true

    delegated_type :postable, types: Postable.types

    after_commit :invalidate_project_time_cache, on: [ :create, :destroy ]
    after_commit :increment_devlogs_count, on: :create
    after_commit :decrement_devlogs_count, on: :destroy

    # These are automatically generated scopes for each postable type:
    # ie. Post.of_devlogs
    # ie. Post.of_devlogs(join: true).where(post_devlogs: { tutorial: false })
    Postable.types.each do |type_class|
      scope_name = "of_#{type_class.demodulize.underscore.pluralize}"
      table_name = type_class.constantize.table_name

      define_singleton_method(scope_name) do |join: false|
        scope = where(postable_type: type_class)
        scope = scope.joins("INNER JOIN #{table_name} ON posts.postable_id = #{table_name}.id") if join
        scope
      end
    end

    # For multiple types, use .with to create a CTE with UNION ALL:
    #   Post.with(
    #     available_posts: [
    #       Post.of_devlogs(join: true).where(post_devlogs: { tutorial: false }),
    #       Post.of_ship_events(join: true),
    #       Post.of_fire_events(join: true)
    #     ]
    #   ).from("available_posts AS posts")

    private

    def invalidate_project_time_cache
      return unless postable_type == "Post::Devlog"

      Rails.cache.delete("project/#{project_id}/time_seconds")
    end

    def increment_devlogs_count
      return unless postable_type == "Post::Devlog"

      Project.unscoped.where(id: project_id).update_counters(devlogs_count: 1)
    end

    def decrement_devlogs_count
      return unless postable_type == "Post::Devlog"

      Project.unscoped.where(id: project_id).update_counters(devlogs_count: -1)
    end
end
