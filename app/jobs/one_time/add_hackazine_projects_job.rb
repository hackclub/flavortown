class OneTime::AddHackazineProjectsJob < ApplicationJob
    queue_as :literally_whenever

    def perform
        sidequest = Sidequest.find_by(slug: "hackazine")
        return unless sidequest

        project_ids = [ 2935, 140, 7256, 6494, 2381, 1865, 3984, 781 ]

        project_ids.each do |project_id|
            project = Project.find_by(id: project_id)

            if project
                entry = sidequest.sidequest_entries.find_or_create_by!(project: project)
                entry.update_column(:aasm_state, "approved")
            end
        end
    end
end
