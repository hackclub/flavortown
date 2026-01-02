# == Schema Information
#
# Table name: ship_certifications
#
#  id                    :bigint           not null, primary key
#  judgement             :integer          default("pending"), not null
#  ysws_feedback_reasons :jsonb
#  ysws_returned_at      :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  project_id            :bigint           not null
#  reviewer_id           :bigint
#  ysws_returned_by_id   :bigint
#
# Indexes
#
#  index_ship_certifications_on_project_id           (project_id)
#  index_ship_certifications_on_reviewer_id          (reviewer_id)
#  index_ship_certifications_on_ysws_returned_by_id  (ysws_returned_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#  fk_rails_...  (ysws_returned_by_id => users.id)
#
class ShipCertification < ApplicationRecord
  YSWS_FEEDBACK_REASONS = [
    "Devlog content does not match claimed work",
    "Time logged appears inflated",
    "Project appears incomplete or non-functional",
    "Repository does not contain expected code",
    "Demo link is broken or inaccessible",
    "Video does not demonstrate claimed features",
    "Suspected use of AI-generated code without disclosure",
    "Other (see notes)"
  ].freeze

  belongs_to :project
  belongs_to :reviewer, class_name: "User", optional: true
  belongs_to :ysws_returned_by, class_name: "User", optional: true

  enum :judgement, { pending: 0, approved: 1, rejected: 2 }

  has_paper_trail

  scope :approved, -> { where(judgement: :approved) }
  scope :pending, -> { where(judgement: :pending) }

  def return_to_certifier!(user:, reasons:)
    update!(
      ysws_returned_by: user,
      ysws_returned_at: Time.current,
      ysws_feedback_reasons: reasons,
      judgement: :pending
    )
  end
end
