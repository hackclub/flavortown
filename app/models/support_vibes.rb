# == Schema Information
#
# Table name: support_vibes
#
#  id                 :bigint           not null, primary key
#  concerns           :jsonb
#  notable_quotes     :jsonb
#  overall_sentiment  :decimal(3, 2)
#  period_end         :datetime
#  period_start       :datetime
#  rating             :string
#  unresolved_queries :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_support_vibes_on_period_start  (period_start)
#
class SupportVibes < ApplicationRecord
  validates :rating, inclusion: { in: %w[low medium high], allow_nil: true }

  def sentiment_label
    return "Neutral" unless overall_sentiment

    if overall_sentiment > 0.3
      "Positive"
    elsif overall_sentiment < -0.3
      "Negative"
    else
      "Neutral"
    end
  end
end
