namespace :images do
  desc "Generate optimized webp and avif versions from source images (PNG, JPG, JPEG)"
  task optimize: :environment do
    require "vips"

    source_extensions = %w[.png .jpg .jpeg]
    target_formats = %w[webp avif]
    images_path = Rails.root.join("app/assets/images")

    source_files = Dir.glob("#{images_path}/**/*").select do |file|
      File.file?(file) && source_extensions.include?(File.extname(file).downcase)
    end

    puts "Found #{source_files.count} source images to process..."

    source_files.each do |source_file|
      base_path = source_file.sub(/\.(png|jpg|jpeg)$/i, "")

      target_formats.each do |format|
        target_file = "#{base_path}.#{format}"

        if File.exist?(target_file) && File.mtime(target_file) >= File.mtime(source_file)
          next
        end

        begin
          image = Vips::Image.new_from_file(source_file)

          case format
          when "webp"
            image.write_to_file(target_file, strip: true, Q: 80)
          when "avif"
            if Rails.env.production?
              image.write_to_file(target_file, strip: true, Q: 45, effort: 9, speed: 0)
            else
              image.write_to_file(target_file, strip: true, Q: 50, effort: 4, speed: 6)
            end
          end

          source_size = File.size(source_file)
          target_size = File.size(target_file)
          reduction = ((1 - target_size.to_f / source_size) * 100).round(1)

          puts "  #{File.basename(source_file)} → #{format} (#{reduction}% smaller)"
        rescue => e
          puts "  ERROR: #{File.basename(source_file)} → #{format}: #{e.message}"
        end
      end
    end

    puts "Done!"
  end

  desc "Delete all generated webp and avif images"
  task clobber: :environment do
    images_path = Rails.root.join("app/assets/images")
    count = 0

    Dir.glob("#{images_path}/**/*.{webp,avif}").each do |file|
      File.delete(file)
      count += 1
    end

    puts "Deleted #{count} generated images"
  end
end

Rake::Task["assets:precompile"].enhance([ "images:optimize" ])
Rake::Task["assets:clobber"].enhance([ "images:clobber" ])
