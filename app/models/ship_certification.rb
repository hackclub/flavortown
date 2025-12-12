# == Schema Information
#
# Table name: ship_certifications
#
#  id          :bigint           not null, primary key
#  aasm_state  :string           default("pending"), not null
#  decided_at  :datetime
#  feedback    :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  project_id  :bigint           not null
#  reviewer_id :bigint
#
# Indexes
#
#  index_ship_certifications_on_project_id                 (project_id)
#  index_ship_certifications_on_project_id_and_created_at  (project_id,created_at)
#  index_ship_certifications_on_reviewer_id                (reviewer_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
class ShipCertification < ApplicationRecord
  include AASM
  has_paper_trail

  belongs_to :project
  belongs_to :reviewer, class_name: "User", optional: true

  validates :project, presence: true

  aasm column: :aasm_state do
    state :pending, initial: true
    state :approved
    state :rejected

    event :approve do
      transitions from: :pending, to: :approved
      after { self.decided_at = Time.current }
    end

    event :reject do
      transitions from: :pending, to: :rejected
      after { self.decided_at = Time.current }
    end
  end

  scope :latest_for_project, ->(project_id) { where(project_id: project_id).order(created_at: :desc).limit(1) }

  def decided?
    approved? || rejected?
  end
end
