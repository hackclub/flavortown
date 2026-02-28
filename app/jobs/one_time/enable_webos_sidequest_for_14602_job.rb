class OneTime::EnableWebosSidequestFor14602Job < ApplicationJob
    queue_as :literally_whenever

    def perform
        sidequest = Sidequest.find_by!(slug: "webos")
        project = Project.find(14602)
        SidequestEntry.find_or_create_by!(sidequest: sidequest, project: project)
    end
end
