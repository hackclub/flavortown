module Admin
  class PayoutsDashboardController < ApplicationController
    def index
      authorize :admin, :access_payouts_dashboard?
      @cap = LedgerEntry.sum(:amount)

      yesterday = 24.hours.ago
      recent = LedgerEntry.where(created_at: yesterday..)

      @created = recent.where("amount > 0").sum(:amount)
      @destroyed = recent.where("amount < 0").sum(:amount).abs
      @txns = recent.count
      @volume = recent.sum("ABS(amount)")

      spenders = LedgerEntry.joins("JOIN users ON ledger_entries.ledgerable_id = users.id AND ledger_entries.ledgerable_type = 'User'")
                            .where(created_at: yesterday.., amount: ...0)
                            .group("users.id", "users.display_name")
                            .sum("ledger_entries.amount")

      @spenders = spenders.map { |user_data, amount| [ user_data, amount.abs ] }
                          .sort_by { |_, amount| -amount }
                          .first(10)

      holder_balances = LedgerEntry.joins("JOIN users ON ledger_entries.ledgerable_id = users.id AND ledger_entries.ledgerable_type = 'User'")
                                   .group("users.id", "users.display_name")
                                   .sum(:amount)
                                   .select { |_, balance| balance > 0 }
                                   .sort_by { |_, balance| -balance }
                                   .first(10)

      @holders = holder_balances

      @sources = {}
      recent.group(:ledgerable_type).group("amount > 0").sum(:amount).each do |key, amount|
        @sources[key] = amount
      end

      thirty_days_ago = 30.days.ago.beginning_of_day
      
      # Build daily creation/destruction data
      @creation = {}
      @destruction = {}
      
      30.times do |i|
        date = i.days.ago.to_date
        date_start = date.beginning_of_day
        date_end = date.end_of_day
        
        @creation[date] = LedgerEntry.where(created_at: date_start..date_end, amount: 1..).sum("ABS(amount)").to_i
        @destruction[date] = LedgerEntry.where(created_at: date_start..date_end, amount: ..0).sum("ABS(amount)").to_i
      end

      # Build circulation data
      @circulation = {}
      circulation_total = LedgerEntry.where("created_at < ?", thirty_days_ago).sum(:amount).to_i

      30.times do |i|
        date = i.days.ago.to_date
        date_start = date.beginning_of_day
        date_end = date.end_of_day
        
        daily_change = LedgerEntry.where(created_at: date_start..date_end).sum(:amount).to_i
        circulation_total += daily_change
        @circulation[date] = circulation_total
      end

      # Sort in ascending order
      @creation = @creation.sort.to_h
      @destruction = @destruction.sort.to_h
      @circulation = @circulation.sort.to_h

      @types = {}
      LedgerEntry.where(created_at: 7.days.ago..).group(:ledgerable_type).sum("ABS(amount)").each do |type, volume|
        @types[type&.humanize || "Unknown"] = volume
      end

      @recent = LedgerEntry.includes(:ledgerable)
                           .order(created_at: :desc)
                           .limit(100)
    end
  end
end
