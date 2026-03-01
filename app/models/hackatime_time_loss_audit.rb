# == Schema Information
#
# Table name: hackatime_time_loss_audits
#
#  id                      :bigint           not null, primary key
#  audited_at              :datetime         not null
#  devlog_total_seconds    :integer          default(0), not null
#  difference_seconds      :integer          default(0), not null
#  hackatime_keys          :text             default(""), not null
#  per_project_sum_seconds :integer          default(0), not null
#  ungrouped_total_seconds :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  project_id              :bigint           not null
#  user_id                 :bigint           not null
#
# Indexes
#
#  index_hackatime_time_loss_audits_on_audited_at          (audited_at)
#  index_hackatime_time_loss_audits_on_difference_seconds  (difference_seconds)
#  index_hackatime_time_loss_audits_on_project_id          (project_id)
#  index_hackatime_time_loss_audits_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class HackatimeTimeLossAudit < ApplicationRecord
  belongs_to :project
  belongs_to :user
end
