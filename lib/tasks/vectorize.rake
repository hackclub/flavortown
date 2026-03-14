namespace :projects do
  desc "Backfill vector embeddings for all projects missing them"
  task vectorize_all: :environment do
    model = Informers.pipeline("embedding", "sentence-transformers/all-mpnet-base-v2")
    scope = Project.needs_embedding

    total = scope.count
    puts "Vectorizing #{total} projects..."

    scope.find_each.with_index do |project, i|
      next if project.searchable_text.strip.length < 10

      embedding = model.(project.searchable_text)
      project.update_column(:embedding, embedding)

      print "\r#{i + 1}/#{total}" if (i + 1) % 50 == 0 || i + 1 == total
    end

    puts "\nDone!"
  end
end
