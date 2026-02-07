require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "should get sitemap xml" do
    get sitemap_url(format: :xml)
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
    assert_includes response.body, "<urlset"
    assert_includes response.body, "<loc>"
  end

  test "sitemap excludes draft projects" do
    draft_project = projects(:one)
    assert_equal "draft", draft_project.ship_status
    get sitemap_url(format: :xml)
    assert_not_includes response.body, project_url(draft_project)
  end

  test "sitemap is publicly cached" do
    get sitemap_url(format: :xml)
    assert_match(/public/, response.headers["Cache-Control"])
  end
end
