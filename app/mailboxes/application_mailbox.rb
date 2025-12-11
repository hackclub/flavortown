class ApplicationMailbox < ActionMailbox::Base
  routing(/^tracking@/i => :tracking)
  routing(/^hcb@/i => :hcb)
  routing all: :incinerate
end
