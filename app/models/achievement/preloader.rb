# frozen_string_literal: true

class Achievement
  class Preloader
    attr_reader :user, :stats

    def initialize(user)
      @user = user
      @stats = load_stats
    end

    def earned?(slug)
      case slug.to_sym
      when :first_login then user.persisted?
      when :identity_verified then user.identity_verified?
      when :first_project then stats[:projects_count] > 0
      when :first_devlog then stats[:has_devlog]
      when :first_comment then stats[:has_commented]
      when :first_order then stats[:has_real_order]
      when :five_orders then stats[:real_orders_count] >= 5
      when :ten_orders then stats[:real_orders_count] >= 10
      when :five_projects then stats[:projects_count] >= 5
      when :first_ship then stats[:has_shipped]
      when :ship_certified then stats[:has_approved]
      when :ten_devlogs then stats[:devlogs_count] >= 10
      when :scrapbook_devlog then stats[:has_scrapbook_devlog]
      when :cooking then stats[:has_fire_project]
      else
        Achievement.find(slug).earned_check.call(user)
      end
    end

    def progress_for(slug)
      case slug.to_sym
      when :five_orders then { current: stats[:real_orders_count], target: 5 }
      when :ten_orders then { current: stats[:real_orders_count], target: 10 }
      when :five_projects then { current: stats[:projects_count], target: 5 }
      when :ten_devlogs then { current: stats[:devlogs_count], target: 10 }
      else
        Achievement.find(slug).progress&.call(user)
      end
    end

    private

    def load_stats
      project_ids = user.project_ids

      project_stats = if project_ids.any?
        Project.where(id: project_ids).pick(
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(*) FILTER (WHERE shipped_at IS NOT NULL)"),
          Arel.sql("COUNT(*) FILTER (WHERE ship_status = 'approved')"),
          Arel.sql("COUNT(*) FILTER (WHERE marked_fire_at IS NOT NULL)")
        )
      else
        [0, 0, 0, 0]
      end

      devlog_stats = if project_ids.any?
        Post.where(project_id: project_ids, postable_type: "Post::Devlog").pick(
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(*) > 0")
        ) || [0, false]
      else
        [0, false]
      end

      has_scrapbook = if project_ids.any?
        Post::Devlog.joins("INNER JOIN posts ON CAST(posts.postable_id AS bigint) = post_devlogs.id AND posts.postable_type = 'Post::Devlog'")
          .where(posts: { project_id: project_ids })
          .where.not(scrapbook_url: nil)
          .exists?
      else
        false
      end

      order_stats = user.shop_orders.real.worth_counting.pick(
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(*) > 0")
      ) || [0, false]

      has_real_order = user.shop_orders.joins(:shop_item)
        .where.not(shop_item: { type: "ShopItem::FreeStickers" })
        .exists?

      {
        projects_count: project_stats[0] || 0,
        has_shipped: (project_stats[1] || 0) > 0,
        has_approved: (project_stats[2] || 0) > 0,
        has_fire_project: (project_stats[3] || 0) > 0,
        devlogs_count: devlog_stats[0] || 0,
        has_devlog: devlog_stats[1] || false,
        has_scrapbook_devlog: has_scrapbook,
        real_orders_count: order_stats[0] || 0,
        has_real_order: has_real_order,
        has_commented: user.has_commented?
      }
    end
  end
end
