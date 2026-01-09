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
      path = Rails.root.join("tmp", "mock_banner_#{SecureRandom.hex(4)}.png").to_s
      MiniMagick::Tool::Convert.new do |convert|
        convert.size("800x600")
        convert << "gradient:#4a90d9-#357abd"
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

    def create_canvas(gradient_start: "#1a1a2e", gradient_end: "#16213e")
      MiniMagick::Tool::Convert.new do |convert|
        convert.size("#{WIDTH}x#{HEIGHT}")
        convert << "gradient:#{gradient_start}-#{gradient_end}"
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

    def place_image(attachment_or_path, x:, y:, width:, height:, gravity: "NorthWest")
      thumb = process_image(attachment_or_path, width, height)
      return unless thumb

      result = image.composite(thumb) do |c|
        c.gravity gravity
        c.geometry "+#{x}+#{y}"
      end
      result.write(image.path)
      @image = MiniMagick::Image.open(image.path)
    rescue StandardError => e
      Rails.logger.warn("OgImage: Failed to place image: #{e.message}")
    end

    def font_path
      @font_path ||= Rails.root.join("app", "assets", "fonts", "Jua-Regular.ttf").to_s
    end

    private

    def process_image(source, width, height)
      tempfile = Tempfile.new([ "og_img", ".jpg" ])
      tempfile.binmode

      if source.respond_to?(:download)
        tempfile.write(source.download)
      else
        tempfile.write(File.binread(source))
      end
      tempfile.rewind

      thumb = MiniMagick::Image.open(tempfile.path)
      thumb.resize("#{width}x#{height}^")
      thumb.gravity("center")
      thumb.extent("#{width}x#{height}")

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
