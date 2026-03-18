class FloorAndConvertTicketCostToInteger < ActiveRecord::Migration[8.1]
  def up
    ShopItem.where("ticket_cost != FLOOR(ticket_cost)").find_each do |item|
      item.update_columns(ticket_cost: item.ticket_cost.floor)
    end

    safety_assured do
      change_column :shop_items, :ticket_cost, :integer
    end
  end

  def down
    change_column :shop_items, :ticket_cost, :decimal
  end
end
