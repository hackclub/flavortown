# == Schema Information
#
# Table name: shop_suggestions
#
#  id          :bigint           not null, primary key
#  explanation :text
#  item        :text
#  link        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_shop_suggestions_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ShopSuggestion < ApplicationRecord
  belongs_to :user

  validates :item, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :explanation, presence: true, length: { minimum: 10, maximum: 10000 }
  validates :link, allow_blank: true, length: { maximum: 2000 }, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
end
