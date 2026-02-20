namespace :sync do
  desc "Enqueue SyncUsersToAirtableJob"
  task users_to_airtable: :environment do
    puts "Enqueuing SyncUsersToAirtableJob..."
    SyncUsersToAirtableJob.perform_later
  end
end
