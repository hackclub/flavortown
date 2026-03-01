# == Schema Information
#
# Table name: sidequest_entries
#
#  id                       :bigint           not null, primary key
#  aasm_state               :string           default("pending"), not null
#  is_rejection_fee_charged :boolean          default(FALSE), not null
#  rejection_message        :text
#  reviewed_at              :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  project_id               :bigint           not null
#  reviewed_by_id           :bigint
#  sidequest_id             :bigint           not null
#
# Indexes
#
#  index_sidequest_entries_on_aasm_state      (aasm_state)
#  index_sidequest_entries_on_project_id      (project_id)
#  index_sidequest_entries_on_reviewed_by_id  (reviewed_by_id)
#  index_sidequest_entries_on_sidequest_id    (sidequest_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (sidequest_id => sidequests.id)
#
class SidequestEntry < ApplicationRecord
  include AASM
  include Ledgerable

  REJECTION_FEE = 5

  has_paper_trail

  belongs_to :sidequest
  belongs_to :project
  belongs_to :reviewed_by, class_name: "User", optional: true

  scope :pending, -> { where(aasm_state: "pending") }
  scope :approved, -> { where(aasm_state: "approved") }
  scope :rejected, -> { where(aasm_state: "rejected") }

  aasm do
    state :pending, initial: true
    state :approved
    state :rejected

    event :approve do
      transitions from: :pending, to: :approved
      after do |reviewer|
        self.reviewed_by = reviewer
        self.reviewed_at = Time.current
        save!
        run_sidequest_callback(:on_approve)
      end
    end

    event :reject do
      transitions from: :pending, to: :rejected
      after do |reviewer|
        self.reviewed_by = reviewer
        self.reviewed_at = Time.current
        save!
        charge_rejection_fee! if is_rejection_fee_charged?
        run_sidequest_callback(:on_reject)
      end
    end
  end

  def project_owner
    project.memberships.find_by(role: "owner")&.user
  end

  private

  def charge_rejection_fee!
    user = project_owner
    return unless user

    user.ledger_entries.create!(
      amount: -REJECTION_FEE,
      reason: "Sidequest rejection fee: #{sidequest.title}",
      created_by: "#{reviewed_by.display_name} (#{reviewed_by.id})",
      ledgerable: self
    )
  end

  # Each sidequest can define callbacks in Sidequest::Callbacks module
  # e.g., Sidequest::Callbacks::Extension.on_approve(entry)
  def run_sidequest_callback(callback_name)
    callback_class = "Sidequest::Callbacks::#{sidequest.slug.classify}".safe_constantize
    return unless callback_class&.respond_to?(callback_name)

    callback_class.public_send(callback_name, self)
  end
end
