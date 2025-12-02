class MyController < ApplicationController
  def balance
    @balance = current_user.ledger_entries.all
  end
end
