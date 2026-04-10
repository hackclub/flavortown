# == Schema Information
#
# Table name: user_vote_verdicts
# Database name: primary
#
#  id            :bigint           not null, primary key
#  assessed_at   :datetime
#  quality_score :float
#  verdict       :string           default("neutral"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :bigint           not null
#
# Indexes
#
#  index_user_vote_verdicts_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User::VoteVerdict < ApplicationRecord
  include AASM

  has_paper_trail on: [ :create, :update ]

  belongs_to :user

  VERDICTS = %w[neutral blessed cursed].freeze

  aasm column: :verdict do
    state :neutral, initial: true
    state :blessed
    state :cursed

    event :bless do
      transitions from: [ :neutral, :cursed ], to: :blessed
    end

    event :curse do
      transitions from: [ :neutral, :blessed ], to: :cursed
    end

    event :restore do
      transitions from: [ :blessed, :cursed ], to: :neutral
    end
  end
end
