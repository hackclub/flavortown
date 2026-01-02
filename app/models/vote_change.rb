class VoteChange < ApplicationRecord
  belongs_to :project
  belongs_to :vote, optional: true
end
