module OgImage
  class MockAttachment
    def initialize(attached: true)
      @attached = attached
    end

    def attached?
      @attached
    end

    def download
      return nil unless @attached
      placeholder_image
    end

    private

    def placeholder_image
      require "open-uri"
      URI.open("https://cataas.com/cat?width=800&height=600").read
    rescue StandardError
      path = Rails.root.join("tmp", "mock_banner_#{SecureRandom.hex(4)}.png").to_s
      MiniMagick::Tool.new("convert") do |convert|
        convert.size("800x600")
        convert << "xc:#e8d5b7"
        convert << path
      end
      data = File.binread(path)
      FileUtils.rm_f(path)
      data
    end
  end

  class MockMemberships
    def initialize(owner_name:)
      @owner_name = owner_name
    end

    def find_by(role:)
      return nil unless role == :owner
      OpenStruct.new(user: OpenStruct.new(display_name: @owner_name))
    end
  end

  class Base
    WIDTH = 1200
    HEIGHT = 630

    attr_reader :image

    def initialize
      @temp_files = []
      @temp_paths = {}
    end

    def render
      raise NotImplementedError, "Subclasses must implement #render"
    end

    def to_png
      render
      image.format "png"
      blob = File.binread(image.path)
      cleanup
      blob
    end

    protected

    def create_canvas(gradient_start: "#4d3228", gradient_end: "#5c4033")
      MiniMagick::Tool.new("convert") do |convert|
        convert.size("#{WIDTH}x#{HEIGHT}")
        convert << "gradient:#{gradient_start}-#{gradient_end}"
        convert << temp_path(:canvas)
      end
      @image = MiniMagick::Image.open(temp_path(:canvas))
    end

    def create_patterned_canvas(bg_color: "#e8d5b7")
      pattern_path = Rails.root.join("app", "assets", "images", "mask", "pattern.png").to_s
      MiniMagick::Tool.new("convert") do |convert|
        convert.size("#{WIDTH}x#{HEIGHT}")
        convert << "xc:#{bg_color}"
        convert << pattern_path
        convert.gravity("Center")
        convert.resize("#{WIDTH}x#{HEIGHT}!")
        convert.compose("Multiply")
        convert.composite
        convert << temp_path(:canvas)
      end
      @image = MiniMagick::Image.open(temp_path(:canvas))
    end

    def draw_text(text, x:, y:, size: 48, color: "#ffffff", gravity: "NorthWest")
      image.combine_options do |c|
        c.gravity gravity
        c.fill color
        c.font font_path
        c.pointsize size
        c.draw "text #{x},#{y} '#{escape_text(text)}'"
      end
    end

    def draw_multiline_text(text, x:, y:, size: 48, color: "#ffffff", line_height: 1.4, max_chars: 35, max_lines: 3)
      lines = wrap_text(text, max_chars).take(max_lines)
      spacing = (size * line_height).to_i

      lines.each_with_index do |line, index|
        draw_text(line, x: x, y: y + (index * spacing), size: size, color: color)
      end

      lines.size
    end

    def place_image(attachment_or_path, x:, y:, width:, height:, gravity: "NorthWest", rounded: false, radius: 20, cover: true)
      thumb = process_image(attachment_or_path, width, height, cover: cover)
      return unless thumb

      if rounded
        thumb = apply_rounded_corners(thumb, width, height, radius)
      end

      result = image.composite(thumb) do |c|
        c.gravity gravity
        c.geometry "+#{x}+#{y}"
      end
      result.write(image.path)
      @image = MiniMagick::Image.open(image.path)
    rescue StandardError => e
      Rails.logger.warn("OgImage: Failed to place image: #{e.message}")
    end

    def apply_rounded_corners(img, width, height, radius)
      mask_path = temp_path("mask_#{SecureRandom.hex(4)}")
      rounded_path = temp_path("rounded_#{SecureRandom.hex(4)}")

      MiniMagick::Tool.new("convert") do |convert|
        convert.size("#{width}x#{height}")
        convert << "xc:none"
        convert.fill("white")
        convert.draw("roundrectangle 0,0,#{width - 1},#{height - 1},#{radius},#{radius}")
        convert << mask_path
      end

      MiniMagick::Tool.new("convert") do |convert|
        convert << img.path
        convert << mask_path
        convert.alpha("set")
        convert.compose("DstIn")
        convert.composite
        convert << rounded_path
      end

      MiniMagick::Image.open(rounded_path)
    end

    def font_path
      @font_path ||= Rails.root.join("app", "assets", "fonts", "Jua-Regular.ttf").to_s
    end

    private

    def process_image(source, width, height, cover: true)
      tempfile = Tempfile.new([ "og_img", ".png" ])
      tempfile.binmode

      if source.respond_to?(:download)
        tempfile.write(source.download)
      elsif source.is_a?(String) && source.start_with?("http")
        require "open-uri"
        tempfile.write(URI.open(source).read)
      else
        tempfile.write(File.binread(source))
      end
      tempfile.rewind

      thumb = MiniMagick::Image.open(tempfile.path)

      if cover
        thumb.resize("#{width}x#{height}^")
        thumb.gravity("center")
        thumb.background("none")
        thumb.extent("#{width}x#{height}")
      else
        thumb.resize("#{width}x#{height}")
      end

      @temp_files << tempfile
      thumb
    rescue StandardError => e
      Rails.logger.warn("OgImage: Failed to process image: #{e.message}")
      tempfile&.close
      tempfile&.unlink
      nil
    end

    def wrap_text(text, max_chars)
      words = text.to_s.split
      lines = []
      current_line = ""

      words.each do |word|
        if current_line.empty?
          current_line = word
        elsif (current_line.length + word.length + 1) <= max_chars
          current_line += " #{word}"
        else
          lines << current_line
          current_line = word
        end
      end
      lines << current_line unless current_line.empty?
      lines
    end

    def escape_text(text)
      text.to_s.gsub("\\", "\\\\\\\\").gsub("'", "\\\\'").gsub('"', '\\"')
    end

    def truncate_text(text, length)
      text.to_s.length > length ? "#{text[0, length - 3]}..." : text.to_s
    end

    def temp_path(name)
      @temp_paths[name] ||= Rails.root.join("tmp", "og_#{name}_#{SecureRandom.hex(8)}.png").to_s
    end

    def cleanup
      @temp_paths.each_value { |path| FileUtils.rm_f(path) }
      @temp_files.each do |f|
        f.close
        f.unlink
      rescue StandardError
        nil
      end
    end
  end
end
