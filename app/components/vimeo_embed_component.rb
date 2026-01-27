# frozen_string_literal: true

class VimeoEmbedComponent < ViewComponent::Base
  VIDEOS = {
    what_is_a_ship: {
      id: "1157267554",
      hash: "664d0fac8e",
      title: "What is a Ship?"
    }
  }.freeze

  attr_reader :video_key, :autoplay

  def initialize(video:, autoplay: false)
    @video_key = video.to_sym
    @autoplay = autoplay
    validate_video!
  end

  def video_config
    VIDEOS[@video_key]
  end

  def embed_url
    url = "https://player.vimeo.com/video/#{video_config[:id]}?h=#{video_config[:hash]}"
    url += "&autoplay=1" if autoplay
    url
  end

  def video_title
    video_config[:title]
  end

  def self.video_url(video_key)
    config = VIDEOS[video_key.to_sym]
    raise ArgumentError, "Unknown video: #{video_key}" unless config

    "https://player.vimeo.com/video/#{config[:id]}?h=#{config[:hash]}"
  end

  private

  def validate_video!
    raise ArgumentError, "Unknown video: #{@video_key}" unless VIDEOS.key?(@video_key)
  end
end
