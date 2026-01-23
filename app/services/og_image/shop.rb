module OgImage
  class Shop < IndexPage
    PREVIEWS = {
      "default" => -> { new }
    }.freeze

    def initialize
      super(title: "Shop", subtitle: "Build stuff, then buy stuff!")
    end
  end
end
