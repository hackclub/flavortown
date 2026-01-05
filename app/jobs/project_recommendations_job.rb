class ProjectRecommendationsJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    recommender = Disco::Recommender.new
    project_views = Ahoy::Event.where(name: "Viewed project")
                               .where.not(user_id: nil)
                               .group(:user_id)
                               .group(:project_id)
                               .count

    data = project_views.map do |(user_id, project_id), _|
        { user_id: user_id, item_id: project_id }
      end

    recommender.fit(data)
    recommender.optimize_user_recs
    recommender.optimize_item_recs

    Project.find_each do |project|
      recs = recommender.item_recs(project.id)
      project.update_recommended_projects(recs)
    end

    User.find_each do |user|
      recs = recommender.user_recs(user.id)
      user.update_recommended_projects(recs)
    end
  end
end
