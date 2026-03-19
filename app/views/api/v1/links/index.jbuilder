json.readme_links @readme_links do |p|
  json.extract! p, :id, :title, :readme_url
end

json.demo_links @demo_links do |p|
  json.extract! p, :id, :title, :demo_url
end

json.repo_links @repo_links do |p|
  json.extract! p, :id, :title, :repo_url
end

json.project_links @project_links do |p|
  json.id p[:id]
  json.title p[:title]
  json.link p[:link]
end
