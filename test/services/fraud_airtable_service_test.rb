require "test_helper"

class FraudAirtableServiceTest < Minitest::Test
  def test_feeling_to_score_conversion
    service = FraudAirtableService.new

    assert_equal 1, service.send(:feeling_to_score, "😭")
    assert_equal 1, service.send(:feeling_to_score, "very unhappy")
    assert_equal 2, service.send(:feeling_to_score, "😞")
    assert_equal 2, service.send(:feeling_to_score, "unhappy")
    assert_equal 3, service.send(:feeling_to_score, "😐")
    assert_equal 3, service.send(:feeling_to_score, "neutral")
    assert_equal 4, service.send(:feeling_to_score, "🙂")
    assert_equal 4, service.send(:feeling_to_score, "happy")
    assert_equal 5, service.send(:feeling_to_score, "😄")
    assert_equal 5, service.send(:feeling_to_score, "very happy")
  end

  def test_feeling_to_score_case_insensitive
    service = FraudAirtableService.new

    assert_equal 4, service.send(:feeling_to_score, "HAPPY")
    assert_equal 2, service.send(:feeling_to_score, "UnHappy")
  end

  def test_feeling_to_score_with_whitespace
    service = FraudAirtableService.new

    assert_equal 4, service.send(:feeling_to_score, "  happy  ")
    assert_equal 5, service.send(:feeling_to_score, " very happy ")
  end

  def test_feeling_to_score_nil_or_invalid
    service = FraudAirtableService.new

    assert_nil service.send(:feeling_to_score, nil)
    assert_nil service.send(:feeling_to_score, "invalid")
    assert_nil service.send(:feeling_to_score, "")
  end

  def test_feeling_to_score_integer_values
    service = FraudAirtableService.new

    assert_equal 1, service.send(:feeling_to_score, 1)
    assert_equal 2, service.send(:feeling_to_score, 2)
    assert_equal 3, service.send(:feeling_to_score, 3)
    assert_equal 4, service.send(:feeling_to_score, 4)
    assert_equal 5, service.send(:feeling_to_score, 5)
  end

  def test_calculate_average_scores_empty_records
    service = FraudAirtableService.new
    result = service.send(:calculate_average_scores, [])

    assert_equal({ total_responses: 0 }, result)
  end

  def test_calculate_average_scores_with_valid_data
    service = FraudAirtableService.new
    records = [
      {
        feeling: "happy",
        shop_order_feeling: "very happy",
        reports_order_feeling: "neutral"
      },
      {
        feeling: "very happy",
        shop_order_feeling: "happy",
        reports_order_feeling: "happy"
      }
    ]

    result = service.send(:calculate_average_scores, records)

    assert_equal 4.5, result[:avg_feeling]
    assert_equal 4.5, result[:avg_shop_order_feeling]
    assert_equal 3.5, result[:avg_reports_order_feeling]
    assert_equal 2, result[:total_responses]
  end

  def test_calculate_average_scores_with_nil_values
    service = FraudAirtableService.new
    records = [
      {
        feeling: "happy",
        shop_order_feeling: nil,
        reports_order_feeling: "happy"
      },
      {
        feeling: nil,
        shop_order_feeling: "happy",
        reports_order_feeling: nil
      }
    ]

    result = service.send(:calculate_average_scores, records)

    assert_equal 4, result[:avg_feeling]
    assert_equal 4, result[:avg_shop_order_feeling]
    assert_equal 4, result[:avg_reports_order_feeling]
    assert_equal 2, result[:total_responses]
  end
end
