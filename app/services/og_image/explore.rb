module OgImage
  class Explore < IndexPage
    PREVIEWS = {
      "default" => -> { new }
    }.freeze

    def initialize
      super(title: "Explore", subtitle: "Discover what teens are building")
    end
  end
end
