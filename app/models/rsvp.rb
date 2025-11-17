# == Schema Information
#
# Table name: rsvps
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Rsvp < ApplicationRecord
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  before_validation :downcase_email
  after_commit :send_signup_confirmation_email, on: :create
  after_create :set_event_in_loops

  private

  def send_signup_confirmation_email
    #    user = User.find_or_create_by!(email: email)
    #    user.generate_magic_link_token!
    #    magic_link_url = Rails.application.routes.url_helpers.magic_links_verify_url(
    #      token: user.magic_link_token,
    #      **Rails.application.config.action_mailer.default_url_options
    #    )

    mail = RsvpMailer.signup_confirmation(email, magic_link_url: nil)
    if Rails.env.production?
      mail.deliver_later
    else
      mail.deliver_now
    end
  end

  def set_event_in_loops
    SetRsvpInLoopsJob.perform_later(self.email)
  end

  def downcase_email
    self.email = email.downcase if email.present?
  end
end
