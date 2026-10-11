require "net/http"

module Privacy
  # Verifies the ES256 tokens the privacy hub signs, using the hub's published JWKS.
  # Programs act on these claims only, never on the request body.
  class Token
    ISSUER = "hackclub-privacy".freeze
    AUDIENCE = "flavortown".freeze
    # PRIVACY_JWKS_URL only exists to point local development at a local hub
    JWKS_URL = ENV.fetch("PRIVACY_JWKS_URL", "https://yeet.hackclub.com/.well-known/jwks.json").freeze
    MAX_LIFETIME = 300
    LEEWAY = 30
    JWKS_TTL = 300
    UNKNOWN_KID_REFETCH = 30

    class Invalid < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super("privacy token rejected: #{code}")
      end
    end

    Claims = Data.define(:request_id, :jti, :action, :dry_run, :subject)
    Subject = Data.define(:emails, :slack_id, :identity_id)

    @mutex = Mutex.new
    @keys = {}
    @fetched_at = nil

    class << self
      def verify!(token, audience: AUDIENCE, now: Time.now.to_i)
        raise Invalid, "missing_token" if token.blank?

        parts = token.split(".")
        raise Invalid, "malformed" unless parts.length == 3

        header = decode_json(parts[0])
        raise Invalid, "alg_not_allowed" unless header["alg"] == "ES256"
        raise Invalid, "invalid_typ" unless header["typ"] == "JWT"

        key = key_for(header["kid"])
        raise Invalid, "bad_signature" unless signature_valid?(key, "#{parts[0]}.#{parts[1]}", decode(parts[2]))

        claims = decode_json(parts[1])
        check_claims!(claims, audience, now)
        build(claims)
      end

      # records a verified token's jti and says whether this is its first use. postgres rather than
      # Rails.cache, since a cache that can't be written would make every token look replayed
      def first_use!(jti)
        connection = ActiveRecord::Base.connection
        connection.exec_delete("DELETE FROM privacy_token_uses WHERE used_at < now() - interval '1 day'")
        inserted = connection.exec_update(ActiveRecord::Base.sanitize_sql([
          "INSERT INTO privacy_token_uses (jti, used_at) VALUES (?, now()) ON CONFLICT DO NOTHING", jti
        ]))
        inserted == 1
      end

      private

      def check_claims!(claims, audience, now)
        raise Invalid, "invalid_iss" unless claims["iss"] == ISSUER
        raise Invalid, "invalid_aud" unless claims["aud"] == audience
        iat = claims["iat"]
        exp = claims["exp"]
        raise Invalid, "invalid_lifetime" unless iat.is_a?(Integer) && exp.is_a?(Integer) && exp - iat <= MAX_LIFETIME
        raise Invalid, "expired" if exp + LEEWAY < now
        raise Invalid, "invalid_iat" if iat - LEEWAY > now
        raise Invalid, "invalid_jti" unless claims["jti"].is_a?(String) && claims["jti"].present?
        raise Invalid, "invalid_request_id" unless claims["request_id"].is_a?(String) && claims["request_id"].present?
        raise Invalid, "invalid_action" unless %w[delete export].include?(claims["action"])
        raise Invalid, "invalid_dry_run" unless [ true, false ].include?(claims["dry_run"])
      end

      def build(claims)
        subject = claims["subject"]
        raise Invalid, "invalid_subject" unless subject.is_a?(Hash)

        emails = subject["emails"]
        slack_id = subject["slack_id"]
        identity_id = subject["identity_id"]
        valid = emails.is_a?(Array) && emails.all? { |email| email.is_a?(String) && email.present? } &&
          (slack_id.nil? || (slack_id.is_a?(String) && slack_id.present?)) &&
          (identity_id.nil? || (identity_id.is_a?(String) && identity_id.present?))
        raise Invalid, "invalid_subject" unless valid

        Claims.new(
          request_id: claims["request_id"],
          jti: claims["jti"],
          action: claims["action"],
          dry_run: claims["dry_run"],
          subject: Subject.new(emails: emails.map { |email| email.strip.downcase }, slack_id:, identity_id:)
        )
      end

      def signature_valid?(key, signing_input, signature)
        return false unless signature.bytesize == 64

        r = OpenSSL::BN.new(signature.byteslice(0, 32), 2)
        s = OpenSSL::BN.new(signature.byteslice(32, 32), 2)
        der = OpenSSL::ASN1::Sequence([ OpenSSL::ASN1::Integer(r), OpenSSL::ASN1::Integer(s) ]).to_der
        key.verify("SHA256", der, signing_input)
      rescue OpenSSL::PKey::PKeyError
        false
      end

      def key_for(kid)
        raise Invalid, "unknown_kid" unless kid.is_a?(String) && kid.present?

        @mutex.synchronize do
          refresh! if @fetched_at.nil? || Time.now - @fetched_at > JWKS_TTL
          refresh! if !@keys.key?(kid) && Time.now - @fetched_at > UNKNOWN_KID_REFETCH
          @keys.fetch(kid) { raise Invalid, "unknown_kid" }
        end
      end

      def refresh!
        uri = URI(JWKS_URL)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 5) do |http|
          http.get(uri.request_uri, "Accept" => "application/json")
        end
        raise Invalid, "jwks_unavailable" unless response.is_a?(Net::HTTPSuccess)

        keys = JSON.parse(response.body).fetch("keys")
        @keys = keys.filter_map { |jwk| [ jwk["kid"], public_key(jwk) ] if usable?(jwk) }.to_h
        @fetched_at = Time.now
      rescue JSON::ParserError, KeyError, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout
        raise Invalid, "jwks_unavailable"
      end

      def usable?(jwk)
        jwk.is_a?(Hash) && jwk["kty"] == "EC" && jwk["crv"] == "P-256" && jwk["kid"].is_a?(String) &&
          (jwk["alg"].nil? || jwk["alg"] == "ES256") && (jwk["use"].nil? || jwk["use"] == "sig")
      end

      def public_key(jwk)
        x = decode(jwk["x"])
        y = decode(jwk["y"])
        raise Invalid, "jwks_unavailable" unless x.bytesize == 32 && y.bytesize == 32

        point = OpenSSL::ASN1::BitString("\x04".b + x + y)
        algorithm = OpenSSL::ASN1::Sequence([ OpenSSL::ASN1::ObjectId("id-ecPublicKey"), OpenSSL::ASN1::ObjectId("prime256v1") ])
        OpenSSL::PKey::EC.new(OpenSSL::ASN1::Sequence([ algorithm, point ]).to_der)
      end

      def decode(segment)
        Base64.urlsafe_decode64(segment.to_s + "=" * ((4 - segment.to_s.length % 4) % 4))
      rescue ArgumentError
        raise Invalid, "malformed"
      end

      def decode_json(segment)
        value = JSON.parse(decode(segment))
        raise Invalid, "malformed" unless value.is_a?(Hash)

        value
      rescue JSON::ParserError
        raise Invalid, "malformed"
      end
    end
  end
end
