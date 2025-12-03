module Ledgerable
  extend ActiveSupport::Concern

  included do
    has_many :ledger_entries, as: :ledgerable, dependent: :destroy
  end
end
