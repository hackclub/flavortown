module Admin
    class SpecialActivitiesController < Admin::ApplicationController
        def index
            authorize :admin, :access_special_activities?
        end
    end
end