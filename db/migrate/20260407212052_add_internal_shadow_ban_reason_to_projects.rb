class AddInternalShadowBanReasonToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :internal_shadow_ban_reason, :text
  end
end
