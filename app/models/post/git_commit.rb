# == Schema Information
#
# Table name: post_git_commits
#
#  id            :bigint           not null, primary key
#  additions     :integer          default(0)
#  author_email  :string
#  author_name   :string
#  authored_at   :datetime
#  deletions     :integer          default(0)
#  files_changed :integer          default(0)
#  message       :text
#  sha           :string           not null
#  url           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_post_git_commits_on_sha  (sha) UNIQUE
#
class Post::GitCommit < ApplicationRecord
  include Postable

  validates :sha, presence: true, uniqueness: true

  def short_sha
    sha&.first(7)
  end

  def title
    message&.lines&.first&.strip
  end

  def body
    lines = message&.lines&.drop(1)
    return nil if lines.blank?

    lines.join.strip.presence
  end

  def stats_summary
    parts = []
    parts << "+#{additions}" if additions.to_i > 0
    parts << "-#{deletions}" if deletions.to_i > 0
    parts.join(" / ")
  end
end
