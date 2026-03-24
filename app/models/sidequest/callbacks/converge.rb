# frozen_string_literal: true

module Sidequest::Callbacks
  class Converge
    class << self
      def on_approve(entry)
        user = entry.project_owner
        return unless user

        user.award_achievement!(:sidequest_converge)

        SendSlackDmJob.perform_later(
          user.id,
          nil,
          blocks_path: "notifications/sidequests/converge_approved",
          locals: { entry: entry, user: user }
        )
      end

      def on_reject(entry)
        user = entry.project_owner
        return unless user

        SendSlackDmJob.perform_later(
          user.id,
          nil,
          blocks_path: "notifications/sidequests/converge_rejected",
          locals: { entry: entry, user: user }
        )
      end
    end
  end
end
