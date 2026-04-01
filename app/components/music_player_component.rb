class MusicPlayerComponent < ViewComponent::Base
  def initialize(audio_urls:, default_index: 0)
    @audio_urls = Array(audio_urls)
    @default_index = default_index.clamp(0, @audio_urls.size - 1)
  end

  def default_index
    @default_index
  end

  def audio_urls_json
    @audio_urls.to_json
  end

  def multiple?
    @audio_urls.size > 1
  end
end
