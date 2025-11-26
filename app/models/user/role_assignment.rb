# == Schema Information
#
# Table name: user_role_assignments
#
#  id         :bigint           not null, primary key
#  role       :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_user_role_assignments_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class User::RoleAssignment < ApplicationRecord
  has_paper_trail

  belongs_to :user

  class RoleDefinition
    attr_reader :id, :name, :description

    def initialize(id:, name:, description:)
      @id = id
      @name = name
      @description = description
    end

    ALL = [
      new(id: 0, name: :super_admin, description: "Can do everything an admin can, and also can assign other users admin"),
      new(id: 1, name: :admin, description: "Can do everything except assign or remove admin"),
      new(id: 2, name: :fraud_dept, description: "Can issue negative payouts, cancel grants & shop orders, but not reject or ban users; access to Blazer; access to read-only admin User w/o PII"),
      new(id: 3, name: :project_certifier, description: "Approve/reject if project work meets Shipwright standards"),
      new(id: 4, name: :ysws_reviewer, description: "Can approve/reject projects for YSWS DB"),
      new(id: 5, name: :fulfillment_person, description: "Can approve/reject/on-hold shop orders, fulfill them, and see addresses; access to read-only admin User w/ pII")
    ].freeze

    def self.all
      ALL
    end

    def self.to_h
      ALL.index_by(&:name).transform_values(&:id)
    end
  end

  enum :role, RoleDefinition.to_h

  def role_details
    RoleDefinition.all.find { |r| r.name == role.to_sym }
  end

  validates :user_id, uniqueness: { scope: :role }
end
