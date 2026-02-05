class SidequestsController < ApplicationController
  def index
    @sidequests = Sidequest.all
  end

  def show
    @sidequest = Sidequest.find_by!(slug: params[:id])

    # if sidequest links external, redirect
    if @sidequest.external_page_link.present?
      redirect_to @sidequest.external_page_link, allow_other_host: true and return
    end

    # otherwise, render default show page
  end
end
