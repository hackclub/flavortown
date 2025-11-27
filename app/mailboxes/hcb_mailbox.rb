class HCBMailbox < ApplicationMailbox
  def process
    if mail.subject.include?("You've received a donation for Flavortown")
      amount = mail.body.decoded.match(/\$(\d+\.\d{2})/)[1]
      # grant_code = mail.body.decoded.match(/grants/([a-zA-Z0-9]+)/).split('/').last
    end
  end
end
