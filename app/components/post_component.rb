 # frozen_string_literal: true

 class PostComponent < ViewComponent::Base
  attr_reader :post, :variant
  VARIANTS = %i[fire devlog certified ship].freeze

  def initialize(post:, variant: :devlog, current_user: nil)
     @post = post
    @variant = normalize_variant(variant)
   end

   def author_name
     post.user&.display_name.presence || "System"
   end

   def posted_at_text
     helpers.time_ago_in_words(post.created_at)
   end

   def duration_text
     return nil unless post.postable.respond_to?(:duration_seconds)

     seconds = post.postable.duration_seconds.to_i
     return nil if seconds.zero?

     hours = seconds / 3600
     minutes = (seconds % 3600) / 60
     "#{hours}h #{minutes}m"
   end

   def ship_event?
     post.postable.is_a?(Post::ShipEvent)
   end

   def attachments
     return [] unless post.postable.respond_to?(:attachments)
     post.postable.attachments
   end

   def image?(attachment)
     attachment.content_type.start_with?("image/")
   end

   def video?(attachment)
     attachment.content_type.start_with?("video/")
   end

  def variant_class
    "post--#{variant}"
  end

  private

  def normalize_variant(value)
    symbol = value.to_sym
    return symbol if VARIANTS.include?(symbol)
    :devlog
  end
 end
