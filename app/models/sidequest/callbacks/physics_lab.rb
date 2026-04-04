# frozen_string_literal: true

module Sidequest::Callbacks
  class PhysicsLab
    class << self
      def on_approve(entry)
        user = entry.project_owner
        return unless user

        user.award_achievement!(:sidequest_physics_lab)

        SendSlackDmJob.perform_later(
          user.id,
          nil,
          blocks_path: "notifications/sidequests/physics_lab_approved",
          locals: { entry: entry, user: user }
        )
      end

      def on_reject(entry)
        user = entry.project_owner
        return unless user

        SendSlackDmJob.perform_later(
          user.id,
          nil,
          blocks_path: "notifications/sidequests/physics_lab_rejected",
          locals: { entry: entry, user: user }
        )
      end
    end
  end
end