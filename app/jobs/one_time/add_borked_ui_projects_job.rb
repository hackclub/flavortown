class OneTime::AddBorkedUiProjectsJob < ApplicationJob
    queue_as :literally_whenever

    def perform
        sidequest = Sidequest.find_or_create_by!(slug: "borked_ui_jam") do |record|
            record.title = "Borked UI Jam"
        end

        project_ids = [ 7386, 7898, 7484, 8300, 7867, 8332, 7448, 10092, 10135, 8258, 10246, 10484, 10373 ]

        project_ids.each do |project_id|
            project = Project.find_by(id: project_id)

            if project
                entry = sidequest.sidequest_entries.find_or_create_by!(project: project)
                entry.update_column(:aasm_state, "approved")
            end
        end
    end
end
