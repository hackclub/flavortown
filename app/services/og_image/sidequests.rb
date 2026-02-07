module OgImage
  class Sidequests < IndexPage
    PREVIEWS = {
      "default" => -> { new }
    }.freeze

    def initialize
      super(title: "Sidequests", subtitle: "Take on challenges for extra bonuses!")
    end
  end
end
