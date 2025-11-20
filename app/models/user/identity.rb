# == Schema Information
#
# Table name: user_identities
#
#  id                       :bigint           not null, primary key
#  access_token_bidx        :string
#  access_token_ciphertext  :text
#  provider                 :string
#  refresh_token_bidx       :string
#  refresh_token_ciphertext :text
#  uid                      :string
#  username                 :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  hackatime_user_id        :string
#  user_id                  :integer          not null
#
# Indexes
#
#  index_user_identities_on_access_token_bidx               (access_token_bidx)
#  index_user_identities_on_provider_and_hackatime_user_id  (provider,hackatime_user_id) UNIQUE
#  index_user_identities_on_provider_and_uid                (provider,uid) UNIQUE
#  index_user_identities_on_refresh_token_bidx              (refresh_token_bidx)
#  index_user_identities_on_user_id                         (user_id)
#  index_user_identities_on_user_id_and_provider            (user_id,provider) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User::Identity < ApplicationRecord
    belongs_to :user
    has_encrypted :access_token, :refresh_token
    blind_index :access_token, :refresh_token, slow: true
    has_paper_trail only: [ :id, :user_id, :uid, :provider ]

    PROVIDERS = %w[hackatime hack_club].freeze

    validates :provider, :uid, presence: true
    validates :access_token, presence: true, if: -> { provider == "hack_club" }
    validates :provider, inclusion: { in: PROVIDERS }
    validates :uid, uniqueness: { scope: :provider }
    validates :provider, uniqueness: { scope: :user_id }

    before_validation :set_uid_from_hackatime_user_id, if: -> { provider == "hackatime" }

    private

    def sync_hackatime_projects
        return if user.blank?

        begin
            HackatimeService.sync_user_projects(user, uid)
        rescue StandardError => e
            Rails.logger.warn("Hackatime project sync failed for user #{user.id} (slack_uid=#{uid}): #{e.class}: #{e.message}")
        end
    end

    def set_uid_from_hackatime_user_id
        self.uid = hackatime_user_id.to_s if uid.blank? && hackatime_user_id.present?
    end
end
