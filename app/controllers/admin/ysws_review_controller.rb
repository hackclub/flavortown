module Admin
    class YswsReviewController < Admin::ApplicationController
        def index
            authorize :admin, :access_ysws_reviews?
        end
    end
end