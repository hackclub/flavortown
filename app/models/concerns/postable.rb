module Postable
  extend ActiveSupport::Concern

  included do
    has_one :post, as: :postable, dependent: :destroy, touch: true
  end
end
