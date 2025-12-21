namespace :assets do
  desc "Convert PNG/JPG assets to AVIF"
  task :avif do
    require "vips"

    Dir.glob("public/assets/**/*.{png,jpg,jpeg}").each do |file|
      avif_file = "#{file}.avif"
      next if File.exist?(avif_file)

      puts "Converting #{file}..."
      image = Vips::Image.new_from_file(file)
      image.write_to_file(avif_file, strip: true, Q: 45, effort: 9, speed: 0)
    end
  end
end
