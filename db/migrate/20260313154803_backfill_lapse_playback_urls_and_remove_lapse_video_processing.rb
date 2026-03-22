# This migration exists because for Lapse v1 we were treating Lapse uploads as just a convenience feature - we downloaded the videos from Lapse,
# and reuploaded them to our servers. This changes with Lapse v2.
#
# As we now track timelapse IDs, as well as using the playback URL provided by Lapse directly, we need to figure out what timelapse IDs we were using
# for these legacy timelapse devlogs. Fortunately, we were storing all timelapse attachments with filenames that have the format of "timelapse-<ID>.<extension>".
# This means that for each devlog that has a proper Lapse attachment, we can extract the timelapse ID of.
#
# However - some devlogs uploaded with Lapse failed their processing, as we didn't bypass attachment size limits when uploading them.
# Such devlogs are stuck with their `lapse_video_processing` column set to `true`. These devlogs will NOT change. As we don't have an attachment to get the ID from,
# we unfortunately have to guess which timelapse was used. However, we can make that guess as best as it can be - we know when the devlog was uploaded, so we can simply
# fetch the most recent timelapse that was posted before that date associated with the project's Hackatime key. This is NOT sure-fire, but should be good enough (worst-case scenario,
# we get a different timelapse that's still for the project in question).
class BackfillLapsePlaybackUrlsAndRemoveLapseVideoProcessing < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class PostDevlog < ActiveRecord::Base
    self.table_name = "post_devlogs"
  end

  class MigrationPost < ActiveRecord::Base
    self.table_name = "posts"
  end

  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
    has_many :posts, class_name: "BackfillLapsePlaybackUrlsAndRemoveLapseVideoProcessing::MigrationPost", foreign_key: :project_id
  end

  class MigrationMembership < ActiveRecord::Base
    self.table_name = "project_memberships"
  end

  class MigrationUserIdentity < ActiveRecord::Base
    self.table_name = "user_identities"
  end

  OWNER_ROLE = 0

  class MigrationActiveStorageAttachment < ActiveRecord::Base
    self.table_name = "active_storage_attachments"
  end

  class MigrationActiveStorageBlob < ActiveRecord::Base
    self.table_name = "active_storage_blobs"
  end

  def up
    backfill_finished_devlogs
    backfill_processing_devlogs

    remaining = PostDevlog.where(lapse_video_processing: true).count
    if remaining > 0
      Rails.logger.warn "[LapseMigration] #{remaining} devlog(s) still have lapse_video_processing=true. " \
        "These need manual resolution before the column can be dropped."
    else
      Rails.logger.info "[LapseMigration] All devlogs resolved. The lapse_video_processing column can be safely dropped in a follow-up migration."
    end
  end

  def down
    # This migration only backfills data columns (lapse_timelapse_id, lapse_playback_url, lapse_playback_url_refreshed_at)
    # and flips lapse_video_processing to false on success. No schema changes to reverse.
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Handles the case where lapse_video_processing == false, and attachment matches the format "timelapse-(ID).(extension)".
  # We can extract the exact timelapse ID used in this case.
  def backfill_finished_devlogs
    query = MigrationActiveStorageAttachment
      .joins("INNER JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id")
      .where(record_type: "Post::Devlog", name: "attachments")
      .where("active_storage_blobs.filename ~ ?", "^timelapse-[^.]+\\.[^.]+$")

    Rails.logger.info "[LapseMigration] We found #{query.count} potential unmigrated Lapse devlogs. Migrating them now."

    attachments = query.select("active_storage_attachments.id, active_storage_attachments.record_id, active_storage_blobs.filename")

    seen_devlog_ids = Set.new

    attachments.find_each do |attachment|
      next if seen_devlog_ids.include?(attachment.record_id)
      seen_devlog_ids.add(attachment.record_id)

      devlog = PostDevlog.find_by(id: attachment.record_id)
      next unless devlog
      next if devlog.lapse_video_processing # these are handled in backfill_processing_devlogs
      next if devlog.lapse_timelapse_id.present? && devlog.lapse_playback_url.present? # already backfilled

      filename = attachment.filename.to_s
      match = filename.match(/\Atimelapse-(?<id>[^.]+)\.[^.]+\z/)
      unless match
        Rails.logger.warn("[LapseMigration] Devlog #{devlog.id} matched timelapse filename regex in query, but manual match failed.")
        next
      end

      timelapse_id = match[:id]

      if devlog.lapse_timelapse_id.present? && devlog.lapse_timelapse_id != timelapse_id
        Rails.logger.warn "[LapseMigration] Devlog #{devlog.id} has lapse_timelapse_id=#{devlog.lapse_timelapse_id} but attachment suggests #{timelapse_id}. Trusting lapse_timelapse_id."
        next
      end

      playback_url = fetch_playback_url(timelapse_id)
      if playback_url.blank?
        Rails.logger.error "[LapseMigration] Could not fetch playback URL for timelapse #{timelapse_id} (devlog #{devlog.id}). Skipping."
        next
      end

      devlog.update_columns(
        lapse_timelapse_id: timelapse_id,
        lapse_playback_url: playback_url,
        lapse_playback_url_refreshed_at: Time.current
      )

      Rails.logger.info "[LapseMigration] Devlog #{devlog.id} migrated successfully!"
    end
  end

  # This case is trickier, as we don't have an attachment, but we KNOW this is a Lapse timelapse because of lapse_video_processing == true.
  # We basically have to make an educated guess here. We do this by taking the latest timelapse made before the devlog date that is associated with the project's Hackatime key(s).
  def backfill_processing_devlogs
    devlogs = PostDevlog.where(lapse_video_processing: true)
    Rails.logger.info "[LapseMigration] We found #{devlogs.count} unmigrated Lapse devlogs that are still processing. Fixing and migrating them now."

    devlogs.find_each do |devlog|
      post = MigrationPost.find_by(postable_type: "Post::Devlog", postable_id: devlog.id)
      unless post
        Rails.logger.error "[LapseMigration] No post found for devlog #{devlog.id} with lapse_video_processing=true. Skipping."
        next
      end

      project = MigrationProject.find_by(id: post.project_id)
      unless project
        Rails.logger.error "[LapseMigration] No project found for post #{post.id} (devlog #{devlog.id}). Skipping."
        next
      end

      hackatime_uid = resolve_hackatime_uid(post.user_id, project.id)
      unless hackatime_uid
        Rails.logger.error "[LapseMigration] No hackatime UID for devlog #{devlog.id} (user #{post.user_id}, project #{project.id}). Skipping."
        next
      end

      project_keys = if devlog.hackatime_projects_key_snapshot.present?
        devlog.hackatime_projects_key_snapshot.split(",")
      else
        project_hackatime_keys(project.id)
      end

      unless project_keys.present?
        Rails.logger.error "[LapseMigration] No hackatime project keys for devlog #{devlog.id} (project #{project.id}). Skipping."
        next
      end

      # We can have multiple Hackatime keys, so we do multiple lookups.
      timelapses = []
      project_keys.each do |key|
        result = Lapse::Api::Hackatime.timelapses_for_project(
          hackatime_user_id: hackatime_uid,
          project_key: key
        )

        next unless result.is_a?(Hash) && result["timelapses"].is_a?(Array)
        timelapses.concat(result["timelapses"])
      end

      # We are only interested in timelapses that were made before the devlog was created.
      timelapses = timelapses.select do |t|
        created_at = Time.at(t["createdAt"].to_i / 1000.0) rescue nil
        created_at && created_at < devlog.created_at
      end

      # With Lapse V1, only PUBLIC timelapses could be used with Flavortown.
      timelapses = timelapses.select { |t| t["visibility"] == "PUBLIC" && t["playbackUrl"].present? }

      # Finally, choose the latest timelapse after applying our filters.
      timelapses.sort_by! { |t| -(t["createdAt"].to_i) }
      chosen = timelapses.first

      # No timelapse matches - leave lapse_video_processing=true so it can be retried or manually resolved.
      if chosen.nil?
        Rails.logger.error "[LapseMigration] No matching timelapse found for devlog #{devlog.id} " \
          "(project #{project.id}, user #{post.user_id}, keys #{project_keys}). " \
          "Leaving lapse_video_processing=true for manual resolution."
        next
      end

      devlog.update_columns(
        lapse_timelapse_id: chosen["id"],
        lapse_playback_url: chosen["playbackUrl"],
        lapse_playback_url_refreshed_at: Time.current,
        lapse_video_processing: false
      )

      Rails.logger.info "[LapseMigration] Devlog #{devlog.id} (processing) migrated successfully with timelapse #{chosen['id']}."
    end
  end

  def fetch_playback_url(timelapse_id)
    data = Lapse::Api::Timelapse.query(timelapse_id)
    return nil unless data.is_a?(Hash)

    timelapse = data["timelapse"]
    return nil unless timelapse.is_a?(Hash)

    timelapse["playbackUrl"]
  end

  def resolve_hackatime_uid(user_id, project_id)
    identity = MigrationUserIdentity.find_by(user_id: user_id, provider: "hackatime")
    return identity.uid if identity

    # Hm, weird, we failed to resolve the Hackatime ID for the post author - but they do need Hackatime to post devlogs. Let's try to look up
    # the Hackatime ID by looking at the owner of the project - not the devlog author. This, apparently, can be different
    owner_membership = MigrationMembership.find_by(project_id: project_id, role: OWNER_ROLE)
    return nil unless owner_membership

    identity = MigrationUserIdentity.find_by(user_id: owner_membership.user_id, provider: "hackatime")
    identity&.uid
  end

  def project_hackatime_keys(project_id)
    ActiveRecord::Base.connection.select_values(
      ActiveRecord::Base.sanitize_sql_array(
        [ "SELECT name FROM user_hackatime_projects WHERE project_id = ?", project_id ]
      )
    ).presence
  rescue => e
    Rails.logger.error "[LapseMigration] Error fetching hackatime keys for project #{project_id}: #{e.message}"
    nil
  end
end
