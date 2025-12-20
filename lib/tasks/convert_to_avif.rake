namespace :assets do
  desc "Convert PNG/JPG assets to AVIF"
  task avif: :environment do
    Dir.glob("public/assets/**/*.{png,jpg,jpeg}").each do |file|
      avif_file = "#{file}.avif"
      next if File.exist?(avif_file)

      puts "Converting #{file}..."
      system("avifenc", "--min", "20", "--max", "25", file, avif_file)
    end
  end
end
