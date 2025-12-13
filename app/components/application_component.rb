class ApplicationComponent < Phlex::HTML
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::URLFor
  include Phlex::Rails::Helpers::TimeAgoInWords
  include Phlex::Rails::Helpers::DistanceOfTimeInWords

  register_output_helper :inline_svg_tag
  register_value_helper :policy
  register_output_helper :md

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
