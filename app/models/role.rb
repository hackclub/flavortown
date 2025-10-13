# == Schema Information
#
# Table name: roles
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Role < ApplicationRecord
    has_many :role_assignments, class_name: "User::RoleAssignment", dependent: :restrict_with_error
    has_many :users, through: :role_assignments

    before_validation :normalize!
    validates :name, :description, presence: true
    validates :name, uniqueness: true

    private

    def normalize!
        self.name = name.to_s.strip.downcase
        self.description = description.to_s.strip.downcase
    end
end
