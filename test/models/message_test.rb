# == Schema Information
#
# Table name: messages
#
#  id         :bigint           not null, primary key
#  block_path :string
#  content    :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  sent_by_id :bigint
#  user_id    :bigint           not null
#
# Indexes
#
#  index_messages_on_sent_by_id  (sent_by_id)
#  index_messages_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "valid with content" do
    message = Message.new(user: users(:one), sent_by: users(:two), content: "Hello")
    assert message.valid?
  end

  test "valid with block_path" do
    message = Message.new(user: users(:one), sent_by: users(:two), block_path: "slack_messages/welcome")
    assert message.valid?
  end

  test "invalid without content and block_path" do
    message = Message.new(user: users(:one), sent_by: users(:two))
    assert_not message.valid?
    assert_includes message.errors[:base], "Either content or block path must be provided"
  end

  test "invalid without user" do
    message = Message.new(sent_by: users(:two), content: "Hello")
    assert_not message.valid?
  end

  test "valid without sent_by (system message)" do
    message = Message.new(user: users(:one), content: "Hello")
    assert message.valid?
  end
end
