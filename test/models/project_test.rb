# == Schema Information
#
# Table name: projects
#
#  id                :bigint           not null, primary key
#  demo_url          :text
#  description       :text
#  memberships_count :integer          default(0), not null
#  project_type      :string
#  readme_url        :text
#  repo_url          :text
#  ship_status       :string           default("draft")
#  shipped_at        :datetime
#  title             :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
