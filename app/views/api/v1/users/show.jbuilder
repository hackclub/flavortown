json.extract! @user, :id, :slack_id, :display_name, :avatar

json.project_ids @user.projects.pluck(:id)
json.vote_count @user.votes.count
json.like_count @user.likes.count

json.devlog_seconds_total @user.devlog_seconds_total
json.devlog_seconds_today @user.devlog_seconds_today

if @user.leaderboard_optin?
    json.cookies @user.cached_balance

    json.balance_history @user.ledger_entries.order(created_at: :desc) do |entry|
        json.amount entry.amount
        json.source_type case entry.ledgerable_type
        when "ShopOrder" then "shop_purchase"
        when "Post::ShipEvent" then "ship_event_payout"
        when "User" then "user_grant"
        when "User::Achievement" then "achievement"
        when "FulfillmentPayoutLine" then "fulfillment_payout"
        when "SidequestEntry" then "sidequest_rejection_fee"
        when "ShowAndTellAttendance" then "show_and_tell_payout"
        else entry.ledgerable_type.underscore.humanize.downcase
        end

        json.created_at entry.created_at
    end
else
    json.cookies nil
    json.balance_history nil
end
