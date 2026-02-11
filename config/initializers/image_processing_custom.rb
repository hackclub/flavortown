# frozen_string_literal: true

begin
  require "image_processing/vips"
rescue LoadError
  Rails.logger.warn("libvips not available, skipping custom VIPS processors")
  return
end

module ImageProcessing
  module Vips
    class Processor < ImageProcessing::Processor
      def crop_to_content(_value = true)
        return image unless image.has_alpha?

        alpha = image.extract_band(image.bands - 1)
        left, top, width, height = alpha.find_trim(threshold: 0, background: [ 0 ])
        return image if width <= 0 || height <= 0

        image.crop(left, top, width, height)
      end
    end
  end
end
