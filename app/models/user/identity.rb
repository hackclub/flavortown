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
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  user_id                  :integer          not null
#
# Indexes
#
#  index_user_identities_on_access_token_bidx     (access_token_bidx)
#  index_user_identities_on_provider_and_uid      (provider,uid) UNIQUE
#  index_user_identities_on_refresh_token_bidx    (refresh_token_bidx)
#  index_user_identities_on_user_id               (user_id)
#  index_user_identities_on_user_id_and_provider  (user_id,provider) UNIQUE
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

    PROVIDERS = %w[slack hackatime idv].freeze

    validates :access_token, :provider, :uid, presence: true
    validates :provider, inclusion: { in: PROVIDERS }
    validates :uid, uniqueness: { scope: :provider }
    validates :provider, uniqueness: { scope: :user_id }

    # Slack OpenID does not send display_name in the response. Therefore, we have to manually get it using users.info method. https://docs.slack.dev/authentication/sign-in-with-slack/#response
    after_create :set_display_name, if: -> { provider == "slack" }
    after_create :sync_hackatime_projects, if: -> { provider == "slack" }

    private

    def set_display_name
        return if user.blank?

        slack_token = Slack.respond_to?(:config) ? Slack.config.token : nil
        return if slack_token.blank?

        begin
            client = Slack::Web::Client.new
            response = client.users_info(user: uid)
            slack_user = response.user if response.respond_to?(:user)
            return if slack_user.blank?

            profile = slack_user.profile if slack_user.respond_to?(:profile)
            slack_display_name = profile.display_name if profile && profile.respond_to?(:display_name)
            return if slack_display_name.blank?

            if user.display_name.to_s.strip != slack_display_name.to_s.strip
                user.update(display_name: slack_display_name)
            end
        rescue StandardError => e
            Rails.logger.warn("Slack users.info callback failed for uid=#{uid}: #{e.class}: #{e.message}")
        end
    end

    def sync_hackatime_projects
        return if user.blank?

        begin
            HackatimeService.sync_user_projects(user, uid)
        rescue StandardError => e
            Rails.logger.warn("Hackatime project sync failed for user #{user.id} (slack_uid=#{uid}): #{e.class}: #{e.message}")
        end
    end
end
