module Api
  module V1
    class ProjectsController < ApplicationController
      def index
          @projects = Project.where(deleted_at: nil).page(params[:page]).per(100)
      end

      def show
        @project = Project.find_by!(id: params[:id], deleted_at: nil)
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end
    end
  end
end