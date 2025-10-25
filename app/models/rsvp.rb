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
  after_create :send_welcome_email
  after_create :set_event_in_loops
  
  private

  def send_welcome_email
    RsvpMailer.welcome_email(self).deliver_later
  end
  
  def set_event_in_loops
    SetRsvpInLoopsJob.perform_later(self.email)
  end
  
  def downcase_email
    self.email = email.downcase if email.present?
  end
end
