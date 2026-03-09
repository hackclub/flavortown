namespace :ship_events do
  desc "Purge ship events with no devlog hours and DM the project owner (one-time)"
  task purge_zero_hours: :environment do
    puts "Purging zero-hour ship events..."
    OneTime::PurgeZeroHourShipEventsJob.perform_now
    puts "Done!"
  end
end
