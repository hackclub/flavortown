# == Schema Information
#
# Table name: blazer_audits
#
#  id          :bigint           not null, primary key
#  data_source :string
#  statement   :text
#  created_at  :datetime
#  query_id    :bigint
#  user_id     :bigint
#
# Indexes
#
#  index_blazer_audits_on_created_at  (created_at)
#  index_blazer_audits_on_query_id    (query_id)
#  index_blazer_audits_on_user_id     (user_id)
#
module Blazer
  class Audit < ApplicationRecord
    self.table_name = "blazer_audits"
    
    belongs_to :user, optional: true
    belongs_to :query, class_name: "Blazer::Query", optional: true
    
    # Make audits immutable - prevent updates and deletes
    before_update :prevent_changes
    before_destroy :prevent_deletion
    
    private
    
    def prevent_changes
      raise ActiveRecord::ReadOnlyRecord, "Blazer audit logs cannot be modified"
    end
    
    def prevent_deletion
      raise ActiveRecord::ReadOnlyRecord, "Blazer audit logs cannot be deleted"
    end
  end
end
