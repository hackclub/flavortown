# frozen_string_literal: true

module Admin
  class FulfillmentPayoutsController < ApplicationController
    def index
      authorize :admin, :access_fulfillment_payouts?
      @runs = FulfillmentPayoutRun.order(created_at: :desc).includes(:approved_by_user)
    end

    def show
      authorize :admin, :access_fulfillment_payouts?
      @run = FulfillmentPayoutRun.includes(lines: :user).find(params[:id])
    end

    def approve
      authorize :admin, :approve_fulfillment_payouts?
      @run = FulfillmentPayoutRun.find(params[:id])

      @run.approved_by_user = current_user
      @run.approved_at = Time.current
      @run.approve!

      PaperTrail::Version.create!(
        item_type: "FulfillmentPayoutRun",
        item_id: @run.id,
        event: "approved",
        whodunnit: current_user.id,
        object_changes: { aasm_state: %w[pending_approval approved] }.to_json
      )

      redirect_to admin_fulfillment_payout_path(@run), notice: "Payout run approved. #{@run.total_amount} tickets distributed to #{@run.lines.count} fulfillers."
    end

    def reject
      authorize :admin, :approve_fulfillment_payouts?
      @run = FulfillmentPayoutRun.find(params[:id])

      @run.reject!

      PaperTrail::Version.create!(
        item_type: "FulfillmentPayoutRun",
        item_id: @run.id,
        event: "rejected",
        whodunnit: current_user.id,
        object_changes: { aasm_state: %w[pending_approval rejected] }.to_json
      )

      redirect_to admin_fulfillment_payout_path(@run), notice: "Payout run rejected. Orders have been released for the next run."
    end

    def trigger
      authorize :admin, :approve_fulfillment_payouts?

      Shop::CalculateFulfillmentPayoutsJob.perform_later(manual: true)

      redirect_to admin_fulfillment_payouts_path, notice: "Manual payout calculation has been queued."
    end
  end
end
