module InkthreadableService
  BASE_URL = "https://www.inkthreadable.co.uk"

  class << self
    def _conn
      @conn ||= Faraday.new(url: BASE_URL) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.response :raise_error
      end
    end

    def create_order(data)
      body = data.to_json
      signature = generate_signature(body)

      _conn.post("/api/orders.php") do |req|
        req.params["AppId"] = app_id
        req.params["Signature"] = signature
        req.body = body
      end.body
    end

    def get_order(order_id)
      query_string = "id=#{order_id}"
      signature = generate_signature(query_string)

      _conn.get("/api/order.php") do |req|
        req.params["AppId"] = app_id
        req.params["id"] = order_id
        req.params["Signature"] = signature
      end.body
    end

    def list_orders(params = {})
      query_parts = params.map { |k, v| "#{k}=#{v}" }.sort.join("&")
      signature = generate_signature(query_parts)

      _conn.get("/api/orders.php") do |req|
        req.params["AppId"] = app_id
        params.each { |k, v| req.params[k.to_s] = v }
        req.params["Signature"] = signature
      end.body
    end

    private

    def app_id
      Rails.application.credentials.dig(:inkthreadable, :app_id) ||
        raise("Missing Inkthreadable app_id in credentials. Set credentials.inkthreadable.app_id")
    end

    def secret_key
      Rails.application.credentials.dig(:inkthreadable, :secret_key) ||
        raise("Missing Inkthreadable secret_key in credentials. Set credentials.inkthreadable.secret_key")
    end

    def generate_signature(request_body)
      OpenSSL::HMAC.hexdigest("SHA256", secret_key, request_body)
    end
  end
end
