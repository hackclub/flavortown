class AiService
  def self.call(prompt)
    new.call(prompt)
  end

  def call(prompt)
    uri = URI(api_endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    headers.each { |key, value| request[key] = value }

    request.body = request_body(prompt).to_json
    response = http.request(request)
    json = JSON.parse(response.body)
    extract_content(json)
  end

  private

  def api_endpoint
    raise NotImplementedError, "Subclasses must implement #api_endpoint"
  end

  def headers
    raise NotImplementedError, "Subclasses must implement #headers"
  end

  def request_body(prompt)
    raise NotImplementedError, "Subclasses must implement #request_body"
  end

  def extract_content(json)
    raise NotImplementedError, "Subclasses must implement #extract_content"
  end
end
