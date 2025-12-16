class MusicPlayerComponent < ViewComponent::Base
  attr_reader :audio_url

  def initialize(audio_url:)
    @audio_url = audio_url
  end
end
