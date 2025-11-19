module TheseusService
    BASE_URL = "https://mail.hackclub.com"
    class << self
      def _conn
        @conn ||= Faraday.new url: "#{BASE_URL}".freeze do |faraday|
          faraday.request :json
          faraday.response :mashify
          faraday.response :json
          faraday.response :raise_error
          faraday.headers["Authorization"] = "Bearer #{Rails.application.credentials.theseus.api_key}".freeze
        end
      end
  
      def create_letter_v1(queue, data)
        _conn.post("/api/v1/letter_queues/#{queue}", data).body
      end
  
      def create_warehouse_order(data)
        _conn.post("/api/v1/warehouse_orders", data).body
      end
  
      def get_letter(letter_id)
        _conn.get("/api/v1/letters/#{letter_id}").body
      end
    end
  end