# == Schema Information
#
# Table name: project_ideas
#
#  id         :bigint           not null, primary key
#  content    :text             not null
#  model      :string           not null
#  prompt     :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class ProjectIdea < ApplicationRecord
end
