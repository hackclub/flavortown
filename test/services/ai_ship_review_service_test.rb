require "test_helper"

class AiShipReviewServiceTest < Minitest::Test
  FakeResponse = Struct.new(:status, :body) do
    def success?
      status == 200
    end
  end

  FakePostsScope = Struct.new(:result) do
    def where(*) = self
    def any? = result
  end

  FakeProject = Struct.new(:id, :repo_url, :readme_url, :demo_url, :ai_declaration, :description, :posts, keyword_init: true)

  def setup
    @project = FakeProject.new(
      id: 42,
      repo_url: "https://github.com/hackclub/test",
      readme_url: "https://raw.githubusercontent.com/hackclub/test/main/README.md",
      demo_url: "https://test.hackclub.com",
      ai_declaration: "none",
      description: "A test project",
      posts: FakePostsScope.new(false)
    )
    Rails.cache.clear
  end

  def teardown
    Rails.cache.clear
  end

  def stub_check(value, &block)
    original = AiShipReviewService.method(:check)
    AiShipReviewService.define_singleton_method(:check) do |_project|
      value.respond_to?(:call) ? value.call(_project) : value
    end
    block.call
  ensure
    AiShipReviewService.define_singleton_method(:check, original)
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield
  ensure
    Rails.cache = original
  end

  def stub_faraday_get(response, &block)
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |*_args, &_req_block|
      response.respond_to?(:call) ? response.call : response
    end
    block.call
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  # cache_key

  def test_cache_key_returns_scoped_key_with_project_id
    assert_equal "ai_ship_review/42", AiShipReviewService.cache_key(@project)
  end

  # fetch

  def test_fetch_returns_valid_fallback_when_check_returns_nil
    with_memory_cache do
      stub_check(nil) do
        assert_equal({ "valid" => true }, AiShipReviewService.fetch(@project))
      end
    end
  end

  def test_fetch_caches_result_so_check_is_only_called_once
    call_count = 0
    checker = ->(_p) { call_count += 1; { "valid" => true } }

    with_memory_cache do
      stub_check(checker) do
        AiShipReviewService.fetch(@project)
        AiShipReviewService.fetch(@project)
      end
    end

    assert_equal 1, call_count
  end

  def test_fetch_stores_result_in_cache_under_the_correct_key
    fake = { "valid" => false, "flags" => [] }

    with_memory_cache do
      stub_check(fake) do
        AiShipReviewService.fetch(@project)
      end
      assert_equal fake, Rails.cache.read(AiShipReviewService.cache_key(@project))
    end
  end

  def test_fetch_returns_cached_value_without_calling_check_again
    with_memory_cache do
      Rails.cache.write(AiShipReviewService.cache_key(@project), { "valid" => false })

      stub_check(->(_p) { raise "should not be called" }) do
        result = AiShipReviewService.fetch(@project)
        assert_equal false, result["valid"]
      end
    end
  end

  # check

  def test_check_returns_parsed_response_on_success
    body = { "valid" => true, "flags" => [] }.to_json
    fake_response = FakeResponse.new(200, body)

    stub_faraday_get(fake_response) do
      result = AiShipReviewService.check(@project)
      assert_equal true, result["valid"]
      assert_empty result["flags"]
    end
  end

  def test_check_returns_nil_when_response_is_not_successful
    fake_response = FakeResponse.new(422, "Unprocessable Entity")

    stub_faraday_get(fake_response) do
      assert_nil AiShipReviewService.check(@project)
    end
  end

  def test_check_returns_nil_on_faraday_error
    raiser = -> { raise Faraday::TimeoutError, "timed out" }

    stub_faraday_get(raiser) do
      assert_nil AiShipReviewService.check(@project)
    end
  end

  def test_check_returns_nil_on_json_parse_error
    fake_response = FakeResponse.new(200, "not json {{{")

    stub_faraday_get(fake_response) do
      assert_nil AiShipReviewService.check(@project)
    end
  end
end
