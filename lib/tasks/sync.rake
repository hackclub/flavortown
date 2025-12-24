namespace :sync do
  desc "Sync hackatime data for all users with hackatime linked"
  task hackatime: :environment do
    puts "Syncing hackatime data for all users..."
    
    users = User.joins(:identities).where(user_identities: { provider: "hackatime" }).distinct
    total = users.count
    synced = 0
    failed = 0
    
    users.find_each.with_index do |user, index|
      begin
        result = user.try_sync_hackatime_data!(force: true)
        if result
          synced += 1
          puts "[#{index + 1}/#{total}] Synced hackatime for user #{user.id} (#{user.slack_id})"
        else
          failed += 1
          puts "[#{index + 1}/#{total}] Failed to sync hackatime for user #{user.id} (#{user.slack_id})"
        end
      rescue => e
        failed += 1
        puts "[#{index + 1}/#{total}] Error syncing hackatime for user #{user.id} (#{user.slack_id}): #{e.message}"
        Rails.logger.error "Error syncing hackatime for user #{user.id}: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
    
    puts "\nHackatime sync complete: #{synced} synced, #{failed} failed out of #{total} users"
  end

  desc "Sync devlog durations for all devlogs"
  task devlogs: :environment do
    puts "Syncing devlog durations..."
    
    devlogs = Post::Devlog.all
    
    total = devlogs.count
    synced = 0
    failed = 0
    skipped = 0
    
    devlogs.find_each.with_index do |devlog, index|
      begin
        # Reload to ensure we have the post association loaded
        devlog.reload
        post = devlog.post
        
        unless post
          skipped += 1
          puts "[#{index + 1}/#{total}] Skipped devlog #{devlog.id} (no post)"
          next
        end
        
        unless post.project.hackatime_keys.present?
          skipped += 1
          puts "[#{index + 1}/#{total}] Skipped devlog #{devlog.id} (no hackatime keys)"
          next
        end
        
        result = devlog.recalculate_seconds_coded
        if result
          synced += 1
          puts "[#{index + 1}/#{total}] Synced devlog #{devlog.id} (duration: #{devlog.duration_seconds}s)"
        else
          failed += 1
          puts "[#{index + 1}/#{total}] Failed to sync devlog #{devlog.id}"
        end
      rescue => e
        failed += 1
        puts "[#{index + 1}/#{total}] Error syncing devlog #{devlog.id}: #{e.message}"
        Rails.logger.error "Error syncing devlog #{devlog.id}: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
    
    puts "\nDevlog sync complete: #{synced} synced, #{failed} failed, #{skipped} skipped out of #{total} devlogs"
  end

  desc "Sync all hackatime data and devlogs"
  task all: :environment do
    puts "Starting full sync of hackatime and devlogs...\n\n"
    
    Rake::Task["sync:hackatime"].invoke
    puts "\n"
    Rake::Task["sync:devlogs"].invoke
    
    puts "\nFull sync complete!"
  end
end
