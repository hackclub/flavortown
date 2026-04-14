# == Schema Information
#
# Table name: versions
# Database name: primary
#
#  id             :uuid             not null, primary key
#  event          :string           not null
#  item_type      :string           not null
#  object         :jsonb
#  object_changes :jsonb
#  whodunnit      :string
#  created_at     :datetime
#  item_id        :string           not null
#
# Indexes
#
#  idx_versions_project_report_status       (item_id,created_at) WHERE (((item_type)::text = 'Project::Report'::text) AND (object_changes ? 'status'::text))
#  idx_versions_shop_order_aasm_state       (item_id,created_at) WHERE (((item_type)::text = 'ShopOrder'::text) AND (object_changes ? 'aasm_state'::text))
#  index_versions_on_item_type_and_item_id  (item_type,item_id)
#  index_versions_on_object                 (object) USING gin
#  index_versions_on_object_changes         (object_changes) USING gin
#
module PaperTrail
  class Version < ActiveRecord::Base
    include PaperTrail::VersionConcern

    before_update { raise ActiveRecord::ReadOnlyRecord, "Audit log versions are immutable" }
    before_destroy { raise ActiveRecord::ReadOnlyRecord, "Audit log versions are immutable" }
  end
end
