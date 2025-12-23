# frozen_string_literal: true

require "image_processing/vips"

module ImageProcessing
  module Vips
    class Processor < ImageProcessing::Processor
      # Crops the image to remove fully transparent (alpha = 0) borders.
      def crop_to_content(image, **)
        return image unless image.has_alpha?

        left, top, width, height = image.find_trim(threshold: 0, background: [ 0, 0, 0, 0 ])

        return image if width <= 0 || height <= 0

        image.crop(left, top, width, height)
      end
    end
  end
end
