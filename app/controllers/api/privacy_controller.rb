module Api
  # GDPR endpoints called by the Hack Club privacy hub. Authenticated by the hub's signed
  # token; acts on the token claims only, never on the request body.
  class PrivacyController < ActionController::API
    before_action :authenticate!

    def delete
      respond(Privacy::Eraser.new(@claims.subject).call(dry_run: @claims.dry_run))
    end

    # export delivery is not specified yet, so this reports what would be included without changing anything
    def export
      respond(Privacy::Eraser.new(@claims.subject).call(dry_run: true))
    end

    private

    def authenticate!
      token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
      @claims = Privacy::Token.verify!(token)
      return render(json: { error: "action_mismatch" }, status: :bad_request) unless @claims.action == action_name

      # the hub mints a new jti for every attempt, so a repeat is a replay
      render json: { error: "replayed" }, status: :conflict unless Privacy::Token.first_use!(@claims.jti)
    rescue Privacy::Token::Invalid => e
      status = e.code == "jwks_unavailable" ? :service_unavailable : :unauthorized
      render json: { error: e.code }, status:
    end

    def respond(result)
      Rails.logger.info("privacy #{action_name} request_id=#{@claims.request_id} dry_run=#{@claims.dry_run} found=#{result.found}")
      render json: {
        request_id: @claims.request_id,
        found: result.found,
        dry_run: @claims.dry_run,
        deleted: result.deleted,
        retained: result.retained
      }
    end
  end
end
