module OgImage
  class Extensions < IndexPage
    PREVIEWS = {
      "default" => -> { new }
    }.freeze

    def initialize
      super(title: "Extensions", subtitle: "Browser extensions from the community")
    end
  end
end
