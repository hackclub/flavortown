module ApplicationHelper
  def admin_tool(&block)
    if current_user&.admin?
      content_tag(:div, class: "admin tools-do", &block)
    end
  end

  def dev_tool(&block)
    if Rails.env.development?
      content_tag(:div, class: "dev tools-do", &block)
    end
  end
  def random_carousel_transform
    "rotate(#{rand(-3..3)}deg) scale(#{(rand(97..103).to_f / 100).round(2)}) translateY(#{rand(-8..8)}px)"
  end

  def resp_prize_images(prize)
    variants = prize[:image_variants]

    if variants.present?
      src = variants[:md] || variants[:sm] || variants[:lg] || variants[:original]
      srcset_parts = []
      srcset_parts << "#{variants[:sm]} 160w" if variants[:sm]
      srcset_parts << "#{variants[:md]} 240w" if variants[:md]
      srcset_parts << "#{variants[:lg]} 360w" if variants[:lg]
      srcset_parts << "#{variants[:original]} 800w" if variants[:original]

      image_tag(
        src,
        alt: prize[:name] || "Prize",
        loading: "lazy",
        decoding: "async",
        srcset: srcset_parts.join(", "),
        sizes: "(max-width: 800px) 144px, 224px"
      )
    else
      image_tag(
        prize[:image_url].present? ? prize[:image_url] : "clubhuman.webp",
        alt: prize[:name] || "Prize",
        loading: "lazy",
        decoding: "async"
      )
    end
  end

  def show_signin_button?
    return true if params[:login].to_s == "1"
    if request&.host == "flavortown.hackclub.com"
      return false
    end
    ENV["HIDE_SIGNIN"].to_s != "true"
  end
end
