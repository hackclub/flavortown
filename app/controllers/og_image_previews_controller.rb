class OgImagePreviewsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    skip_authorization
    @previews = OgImage::Preview.all
  end

  def show
    skip_authorization

    preview_class = OgImage::Preview.for(params[:id])
    unless preview_class
      render plain: "Unknown preview: #{params[:id]}", status: :not_found
      return
    end

    png_data = preview_class.to_png

    send_data png_data, type: "image/png", disposition: "inline"
  end
end
