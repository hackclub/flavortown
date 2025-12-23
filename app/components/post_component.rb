 # frozen_string_literal: true

 class PostComponent < ViewComponent::Base
  attr_reader :post, :variant
  VARIANTS = %i[fire devlog certified ship].freeze

  def initialize(post:, variant: :devlog, current_user: nil)
    @post = post
    @variant = normalize_variant(variant)
    @variant = :ship if post.postable.is_a?(Post::ShipEvent)
    @variant = :fire if post.postable.is_a?(Post::FireEvent)
    @current_user = current_user
   end

   def project_title
      if post.project&.title.present?
        post.project&.title
      end
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

   def devlog?
      post.postable.is_a?(Post::Devlog)
    end

   def fire_event?
      post.postable.is_a?(Post::FireEvent)
    end

   def author_activity
     if fire_event?
       "sent their compliments to the chef of"
     elsif ship_event?
       "shipped"
     else
       "worked on"
     end
   end

   def attachments
     return [] unless post.postable.respond_to?(:attachments)
     post.postable.attachments
   end

   def scrapbook_url
     return nil unless post.postable.respond_to?(:scrapbook_url)
     post.postable.scrapbook_url
   end

   def image?(attachment)
     attachment.content_type.start_with?("image/")
   end

   def gif?(attachment)
     attachment.content_type == "image/gif"
   end

   def video?(attachment)
     attachment.content_type.start_with?("video/")
   end

  def variant_class
    "post--#{variant}"
  end

  def commentable
    post.postable
  end

  private

  def normalize_variant(value)
    symbol = value.to_sym
    return symbol if VARIANTS.include?(symbol)
    :devlog
  end
 end
