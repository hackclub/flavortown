class AddYswsFieldsToShipCertifications < ActiveRecord::Migration[8.1]
  def change
    add_column :ship_certifications, :ysws_returned_at, :datetime
    add_column :ship_certifications, :ysws_feedback_reasons, :jsonb, default: []
  end
end
