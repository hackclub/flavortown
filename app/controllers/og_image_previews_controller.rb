class OgImagePreviewsController < ApplicationController
  skip_before_action :verify_authenticity_token
  layout false

  def index
    skip_authorization
    @previews = grouped_previews
  end

  def show
    skip_authorization

    @preview_name = params[:id]
    preview_class = OgImage::Preview.for(@preview_name)

    unless preview_class
      render plain: "Unknown preview: #{@preview_name}", status: :not_found
      return
    end

    respond_to do |format|
      format.html do
        @previews = grouped_previews
      end
      format.png do
        png_data = preview_class.to_png
        send_data png_data, type: "image/png", disposition: "inline"
      end
    end
  end

  private

  def grouped_previews
    OgImage::Preview.all.group_by { |name| name.split("/").first }
  end
end
