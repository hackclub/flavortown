class ActiveUserTracker
  WINDOW_SIZE = 15.minutes.to_i

  class << self
    def track(user_id: nil, session_id:)
      return if session_id.blank?

      current_time = Time.current.to_i

      if user_id.present?
        Rails.cache.write(signed_in_key(user_id), current_time, expires_in: WINDOW_SIZE.seconds)
      else
        Rails.cache.write(anonymous_key(session_id), current_time, expires_in: WINDOW_SIZE.seconds)
      end
    end

    def signed_in_count
      count_keys("active_users:signed_in:*")
    end

    def anonymous_count
      count_keys("active_users:anonymous:*")
    end

    def counts
      { signed_in: signed_in_count, anonymous: anonymous_count }
    end

    private

    def signed_in_key(user_id)
      "active_users:signed_in:#{user_id}"
    end

    def anonymous_key(session_id)
      "active_users:anonymous:#{session_id}"
    end

    def count_keys(pattern)
      cache_store = Rails.cache

      if cache_store.respond_to?(:redis)
        cache_store.redis.then { |conn| conn.keys(pattern).size }
      elsif cache_store.is_a?(ActiveSupport::Cache::MemoryStore)
        cache_store.instance_variable_get(:@data).keys.count { |k| File.fnmatch?(pattern, k) }
      else
        0
      end
    end
  end
end
