module Privacy
  # Finds everyone matching a privacy subject and erases them. Financial, fraud and voting records
  # reference users and projects through many required foreign keys, so the user row and their
  # solely owned projects stay as anonymous placeholders while everything personal is deleted or
  # scrubbed. See docs/privacy.md.
  #
  # A dry run performs the same work inside a transaction, reads the per-table delete counts
  # postgres tracks for that transaction, then rolls back, so dry run and real run report the
  # same numbers. Those counters carry earlier transactions on the same connection until postgres
  # flushes them, so we diff a snapshot.
  class Eraser
    Result = Data.define(:found, :deleted, :retained)

    OPEN_ORDER_STATES = %w[pending awaiting_verification awaiting_verification_call awaiting_periodical_fulfillment on_hold].freeze
    CANCELLATION_NOTE = "Cancelled: account deleted after a privacy request".freeze
    REMOVED_POST_TYPES = %w[Post::Devlog Post::GitCommit].freeze
    PLACEHOLDER = "kept as an anonymous placeholder"

    RETAINED = [
      [ ->(ids) { User.where(id: ids) }, "account record", "#{PLACEHOLDER} so financial records stay linked; name, emails, Slack ID, tokens and login identities removed" ],
      [ ->(ids) { ShopOrder.where(user_id: ids, aasm_state: OPEN_ORDER_STATES) }, "cancelled shop orders", "unfulfilled orders are rejected so nothing ships to a deleted account" ],
      [ ->(ids) { ShopOrder.where(user_id: ids) }, "shop orders", "kept for accounting, fulfilment and customs" ],
      [ ->(ids) { ShopWarehousePackage.where(user_id: ids) }, "shipped packages", "kept for customs and carrier claims" ],
      [ ->(ids) { ShopCardGrant.where(user_id: ids) }, "card grants", "financial records kept for HCB accounting" ],
      [ ->(ids) { LedgerEntry.where(user_id: ids) }, "ledger entries", "kept so balances and payouts stay correct" ],
      [ ->(ids) { FulfillmentPayoutLine.where(user_id: ids) }, "fulfillment payouts", "financial records kept for accounting" ],
      [ ->(ids) { ShowAndTellAttendance.where(user_id: ids) }, "show and tell attendances", "kept because payouts reference them" ],
      [ ->(ids) { User::Achievement.where(user_id: ids) }, "achievements", "kept because rewards in the ledger reference them" ],
      [ ->(ids) { Vote.where(user_id: ids) }, "votes cast", "kept so other projects' rankings and payouts stay stable" ],
      [ ->(ids) { Project::Report.where(reporter_id: ids) }, "reports filed", "kept for fraud prevention" ],
      [ ->(ids) { ShopOrderReview.where(user_id: ids) }, "order reviews", "kept as the record of staff decisions" ]
    ].freeze

    AIRTABLE_REASON = "copies synced to Airtable are not touched here; the privacy hub's Airtable target deletes them".freeze

    def initialize(subject)
      @subject = subject
    end

    def call(dry_run:)
      user_ids = matching_user_ids
      return Result.new(found: false, deleted: {}, retained: []) if user_ids.empty?

      retained = retained_counts(user_ids)
      analytics = erase_analytics!(user_ids, dry_run:)
      deleted = {}
      blob_ids = []
      ActiveRecord::Base.transaction do
        before = delete_counters
        blob_ids = erase!(user_ids)
        deleted = delete_counters.filter_map { |table, count| [ table, count - before.fetch(table, 0) ] if count > before.fetch(table, 0) }.to_h
        raise ActiveRecord::Rollback if dry_run
      end
      deleted.merge!(analytics)
      ActiveStorage::Blob.where(id: blob_ids).find_each(&:purge_later) unless dry_run

      Result.new(found: true, deleted:, retained:)
    end

    private

    def matching_user_ids
      emails = @subject.emails
      scope = User.none
      scope = scope.or(User.where("lower(email) IN (:emails) OR lower(hcb_email) IN (:emails)", emails:)) if emails.any?
      scope = scope.or(User.where(slack_id: @subject.slack_id)) if @subject.slack_id && !@subject.slack_id.start_with?("deleted-")
      if @subject.identity_id
        scope = scope.or(User.where(id: User::Identity.where(provider: "hack_club", uid: @subject.identity_id).select(:user_id)))
      end
      scope.pluck(:id)
    end

    def retained_counts(user_ids)
      sole = sole_project_ids(user_ids)
      retained = RETAINED.filter_map do |scope, type, reason|
        count = scope.call(user_ids).count
        { type:, count:, reason: } if count.positive?
      end
      if sole.any?
        retained << { type: "projects", count: sole.size,
                      reason: "hidden and #{PLACEHOLDER} because ship events, votes and payouts reference them; title, description, links, banner, demo video, devlogs and commits removed" }
      end
      synced = User.where(id: user_ids).where.not(synced_at: nil).count
      retained << { type: "airtable copies", count: synced, reason: AIRTABLE_REASON } if synced.positive?
      retained
    end

    # projects where every current member is being erased
    def sole_project_ids(user_ids)
      Project.unscoped
             .where(id: Project::Membership.where(user_id: user_ids).select(:project_id))
             .where.not(id: Project::Membership.where.not(user_id: user_ids).select(:project_id))
             .pluck(:id)
    end

    def erase!(user_ids)
      sole = sole_project_ids(user_ids)
      member_project_ids = Project::Membership.where(user_id: user_ids).distinct.pluck(:project_id)
      emails = (@subject.emails + User.where(id: user_ids).pluck(:email, :hcb_email).flatten.compact.map(&:downcase)).uniq

      removed_posts = Post.where(postable_type: REMOVED_POST_TYPES)
                          .where(project_id: sole).or(Post.where(postable_type: REMOVED_POST_TYPES, user_id: user_ids))
      devlog_ids = removed_posts.where(postable_type: "Post::Devlog").pluck(:postable_id)
      commit_ids = removed_posts.where(postable_type: "Post::GitCommit").pluck(:postable_id)
      post_ids = removed_posts.pluck(:id)
      touched_project_ids = (sole + member_project_ids + removed_posts.distinct.pluck(:project_id)).uniq
      counters = affected_devlogs(user_ids, devlog_ids)

      records = {
        "User::Identity" => User::Identity.where(user_id: user_ids).pluck(:id),
        "UserProfile" => UserProfile.where(user_id: user_ids).pluck(:id),
        "Project::Membership" => Project::Membership.where(user_id: user_ids).pluck(:id),
        "Comment" => Comment.where(user_id: user_ids).or(Comment.where(commentable_type: "Post::Devlog", commentable_id: devlog_ids)).pluck(:id),
        "Like" => Like.where(user_id: user_ids).or(Like.where(likeable_type: "Post::Devlog", likeable_id: devlog_ids)).pluck(:id),
        "Message" => Message.where(user_id: user_ids).pluck(:id),
        "FunnelEvent" => FunnelEvent.where(user_id: user_ids).or(FunnelEvent.where("lower(email) IN (?)", emails.presence || [ "" ])).pluck(:id),
        "Rsvp" => Rsvp.where("lower(email) IN (?)", emails.presence || [ "" ]).pluck(:id),
        "Post" => post_ids,
        "Post::Devlog" => devlog_ids,
        "Post::GitCommit" => commit_ids
      }

      attachments = ActiveStorage::Attachment.where(record_type: "Post::Devlog", record_id: devlog_ids)
                                             .or(ActiveStorage::Attachment.where(record_type: "Project", record_id: sole))
      blob_ids = attachments.pluck(:blob_id)
      attachments.delete_all

      execute([ "DELETE FROM devlog_versions WHERE devlog_id IN (?)", devlog_ids ]) if devlog_ids.any?
      records.except("Post::Devlog", "Post::GitCommit").each do |type, ids|
        next if ids.empty?

        execute([ "DELETE FROM #{type.constantize.table_name} WHERE id IN (?)", ids ])
      end
      execute([ "DELETE FROM post_devlogs WHERE id IN (?)", devlog_ids ]) if devlog_ids.any?
      execute([ "DELETE FROM post_git_commits WHERE id IN (?)", commit_ids ]) if commit_ids.any?

      %w[flavortime_sessions project_skips project_follows shop_suggestions user_hackatime_projects extension_usages hackatime_time_loss_audits].each do |table|
        execute([ "DELETE FROM #{table} WHERE user_id IN (?)", user_ids ])
      end
      execute([ "DELETE FROM disco_recommendations WHERE (subject_type = 'User' AND subject_id IN (?)) OR (item_type = 'Project' AND item_id IN (?))", user_ids, sole.presence || [ 0 ] ])
      execute([ "DELETE FROM flipper_gates WHERE value IN (?)", user_ids.map { |id| "User;#{id}" } ])

      records.merge("User" => user_ids, "Project" => sole).each do |type, ids|
        next if ids.empty?

        execute([ "DELETE FROM versions WHERE item_type = ? AND item_id IN (?)", type, ids.map(&:to_s) ])
      end
      execute([ "UPDATE versions SET whodunnit = NULL WHERE whodunnit IN (?)", user_ids.map(&:to_s) ])

      execute([ "UPDATE posts SET user_id = NULL WHERE user_id IN (?)", user_ids ])
      execute([ "UPDATE post_git_commits SET author_email = NULL, author_name = NULL WHERE lower(author_email) IN (?)", emails.presence || [ "" ] ])
      scrub_projects!(sole)
      close_open_work!(user_ids)
      anonymize_users!(user_ids)
      recount!(touched_project_ids, counters)
      blob_ids
    end

    # other people's devlogs whose counter caches include likes and comments about to be deleted
    def affected_devlogs(user_ids, devlog_ids)
      (Like.where(user_id: user_ids, likeable_type: "Post::Devlog").pluck(:likeable_id) +
        Comment.where(user_id: user_ids, commentable_type: "Post::Devlog").pluck(:commentable_id)).uniq - devlog_ids
    end

    def scrub_projects!(project_ids)
      return if project_ids.empty?

      ship_event_ids = Post.where(project_id: project_ids, postable_type: "Post::ShipEvent").pluck(:postable_id)
      execute([ "UPDATE post_ship_events SET body = NULL WHERE id IN (?)", ship_event_ids ]) if ship_event_ids.any?
      execute([ <<~SQL, project_ids ])
        UPDATE projects SET title = 'Deleted project', description = NULL, demo_url = NULL, readme_url = NULL,
          repo_url = NULL, ai_declaration = NULL, deleted_at = COALESCE(deleted_at, now())
        WHERE id IN (?)
      SQL
    end

    def close_open_work!(user_ids)
      execute([ <<~SQL, CANCELLATION_NOTE, user_ids, OPEN_ORDER_STATES ])
        UPDATE shop_orders SET aasm_state = 'rejected', rejection_reason = ?, rejected_at = now()
        WHERE user_id IN (?) AND aasm_state IN (?)
      SQL
    end

    def anonymize_users!(user_ids)
      execute([ <<~SQL, user_ids ])
        UPDATE users SET email = NULL, hcb_email = NULL, first_name = NULL, last_name = NULL,
          display_name = 'Deleted user', slack_id = 'deleted-' || id, api_key = NULL, session_token = NULL,
          magic_link_token = NULL, magic_link_token_expires_at = NULL, ref = NULL, enriched_ref = NULL,
          airtable_record_id = NULL, internal_notes = NULL, banned_reason = NULL, club_name = NULL, club_link = NULL,
          regions = '{}', granted_roles = '{}', leaderboard_optin = false, slack_balance_notifications = false,
          send_votes_to_slack = false, updated_at = now()
        WHERE id IN (?)
      SQL
      # entries a reviewer created read "Name (id)"
      user_ids.each do |id|
        execute([ "UPDATE ledger_entries SET created_by = ? WHERE created_by LIKE ?", "Deleted user (#{id})", "% (#{id})" ])
      end
    end

    def recount!(project_ids, devlog_ids)
      if project_ids.any?
        execute([ <<~SQL, project_ids ])
          UPDATE projects SET
            memberships_count = (SELECT count(*) FROM project_memberships WHERE project_memberships.project_id = projects.id),
            devlogs_count = (SELECT count(*) FROM posts WHERE posts.project_id = projects.id AND posts.postable_type = 'Post::Devlog'),
            duration_seconds = (
              SELECT coalesce(sum(post_devlogs.duration_seconds), 0) FROM posts
              JOIN post_devlogs ON post_devlogs.id = posts.postable_id
              WHERE posts.project_id = projects.id AND posts.postable_type = 'Post::Devlog' AND post_devlogs.deleted_at IS NULL
            )
          WHERE id IN (?)
        SQL
      end
      return if devlog_ids.empty?

      execute([ <<~SQL, devlog_ids ])
        UPDATE post_devlogs SET
          likes_count = (SELECT count(*) FROM likes WHERE likes.likeable_type = 'Post::Devlog' AND likes.likeable_id = post_devlogs.id),
          comments_count = (SELECT count(*) FROM comments WHERE comments.commentable_type = 'Post::Devlog' AND comments.commentable_id = post_devlogs.id)
        WHERE id IN (?)
      SQL
    end

    # ahoy lives in its own database when configured, so it can't share the transaction. it goes
    # first so a failure leaves everything else in place for the hub's retry
    def erase_analytics!(user_ids, dry_run:)
      return {} if ENV["AHOY_DB_URL"].blank?

      events = Ahoy::Event.where(user_id: user_ids)
      visits = Ahoy::Visit.where(user_id: user_ids)
      counts = { "ahoy_events" => events.count, "ahoy_visits" => visits.count }.select { |_, count| count.positive? }
      unless dry_run
        events.delete_all
        visits.delete_all
      end
      counts
    end

    def delete_counters
      rows = ActiveRecord::Base.connection.select_rows(<<~SQL)
        SELECT relname, n_tup_del FROM pg_stat_xact_user_tables
        WHERE n_tup_del > 0 AND relname NOT LIKE 'solid_%' ORDER BY relname
      SQL
      rows.to_h { |table, count| [ table, count.to_i ] }
    end

    def execute(statement)
      ActiveRecord::Base.connection.exec_update(ActiveRecord::Base.sanitize_sql(statement))
    end
  end
end
