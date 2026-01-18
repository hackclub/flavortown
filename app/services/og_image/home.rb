module OgImage
  class Home < IndexPage
    PREVIEWS = {
      "default" => -> { new }
    }.freeze

    def initialize
      super(title: "I'm cooked!")
    end
  end
end
