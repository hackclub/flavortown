require "ostruct"

config = YAML.load_file(Rails.root.join("config", "game_constants.yml"))
Rails.application.config.game_constants = OpenStruct.new(config[Rails.env] || config["shared"])
