class OgImageGenerator
  WIDTH = 1200
  HEIGHT = 630

  class << self
    def for_project(project)
      new.generate_project(project)
    end
  end

  def generate_project(project)
    image = create_base_image

    add_title(image, project.title)
    add_subtitle(image, subtitle_for_project(project))
    add_branding(image)

    if project.banner.attached?
      add_thumbnail(image, project.banner)
    end

    finalize(image)
  end

  private

  def create_base_image
    MiniMagick::Tool::Convert.new do |convert|
      convert.size("#{WIDTH}x#{HEIGHT}")
      convert << "gradient:#1a1a2e-#16213e"
      convert << temp_path(:base)
    end
    MiniMagick::Image.open(temp_path(:base))
  end

  def add_title(image, title)
    lines = wrap_text(title, 35)
    y_offset = 180

    lines.each_with_index do |line, index|
      image.combine_options do |c|
        c.gravity "NorthWest"
        c.fill "#ffffff"
        c.font font_path
        c.pointsize 52
        c.draw "text 60,#{y_offset + (index * 70)} '#{escape_text(line)}'"
      end
    end
  end

  def add_subtitle(image, subtitle)
    return if subtitle.blank?

    y_position = 180 + (wrap_text(image.path.include?("title") ? "" : "", 35).size * 70) + 100
    y_position = [ y_position, 350 ].max

    image.combine_options do |c|
      c.gravity "NorthWest"
      c.fill "#aaaaaa"
      c.font font_path
      c.pointsize 28
      c.draw "text 60,#{y_position} '#{escape_text(truncate_text(subtitle, 60))}'"
    end
  end

  def add_branding(image)
    image.combine_options do |c|
      c.gravity "SouthWest"
      c.fill "#666666"
      c.font font_path
      c.pointsize 24
      c.draw "text 60,50 'flavortown.hackclub.com'"
    end
  end

  def add_thumbnail(image, attachment)
    thumb = download_and_resize_attachment(attachment, 400, 300)
    return unless thumb

    result = image.composite(thumb) do |c|
      c.gravity "East"
      c.geometry "+60+0"
    end
    result.write(image.path)
  rescue StandardError => e
    Rails.logger.warn("OgImageGenerator: Failed to add thumbnail: #{e.message}")
  end

  def finalize(image)
    image.format "png"
    blob = File.binread(image.path)
    cleanup_temp_files
    blob
  end

  def subtitle_for_project(project)
    owner = project.memberships.find_by(role: :owner)&.user
    parts = []
    parts << "by #{owner.display_name}" if owner
    parts << "#{project.devlogs_count} devlogs" if project.devlogs_count.positive?
    parts.join(" · ")
  end

  def download_and_resize_attachment(attachment, width, height)
    tempfile = Tempfile.new([ "og_thumb", ".jpg" ])
    tempfile.binmode
    tempfile.write(attachment.download)
    tempfile.rewind

    thumb = MiniMagick::Image.open(tempfile.path)
    thumb.resize("#{width}x#{height}^")
    thumb.gravity("center")
    thumb.extent("#{width}x#{height}")

    @temp_files ||= []
    @temp_files << tempfile

    thumb
  rescue StandardError => e
    Rails.logger.warn("OgImageGenerator: Failed to process thumbnail: #{e.message}")
    tempfile&.close
    tempfile&.unlink
    nil
  end

  def font_path
    @font_path ||= Rails.root.join("app", "assets", "fonts", "Jua-Regular.ttf").to_s
  end

  def escape_text(text)
    text.to_s.gsub("'", "\\\\'").gsub('"', '\\"').gsub("\\", "\\\\\\")
  end

  def truncate_text(text, length)
    text.to_s.length > length ? "#{text[0, length - 3]}..." : text.to_s
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
    lines.take(3)
  end

  def temp_path(name)
    @temp_paths ||= {}
    @temp_paths[name] ||= Rails.root.join("tmp", "og_#{name}_#{SecureRandom.hex(8)}.png").to_s
  end

  def cleanup_temp_files
    @temp_paths&.each_value { |path| FileUtils.rm_f(path) }
    @temp_files&.each do |f|
      f.close
      f.unlink
    rescue StandardError
      nil
    end
  end
end
