# Required because dartsass was only building application.scss by default
Rails.application.config.dartsass.builds = {
  "." => "."
}
# Rails.application.config.dartsass.build_options = ['--no-charset', '--embed-sources']
