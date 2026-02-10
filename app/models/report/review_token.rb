# == Schema Information
#
# Table name: report_review_tokens
#
#  id         :bigint           not null, primary key
#  action     :string           not null
#  expires_at :datetime         not null
#  token      :string           not null
#  used_at    :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  report_id  :bigint           not null
#
# Indexes
#
#  index_report_review_tokens_on_report_id             (report_id)
#  index_report_review_tokens_on_report_id_and_action  (report_id,action) UNIQUE
#  index_report_review_tokens_on_token                 (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (report_id => project_reports.id)
#
class Report::ReviewToken < ApplicationRecord
  self.table_name = "report_review_tokens"

  belongs_to :report, class_name: "Project::Report"

  ACTIONS = %w[review dismiss].freeze
  TOKEN_EXPIRY = 30.days

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  scope :pending, -> { where(used_at: nil).where("expires_at > ?", Time.current) }
  scope :valid, -> { pending }

  before_validation :generate_token, :set_expiry, on: :create

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= TOKEN_EXPIRY.from_now
  end
end
