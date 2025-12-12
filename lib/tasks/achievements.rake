# frozen_string_literal: true

namespace :achievements do
  desc "Generate silhouette versions of achievement icons"
  task generate_silhouettes: :environment do
    AchievementSilhouettes.generate!
  end
end

Rake::Task["assets:precompile"].enhance([ "achievements:generate_silhouettes" ])
