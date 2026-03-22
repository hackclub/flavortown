class VotingCooldownService
  include ActionView::Helpers::DateHelper

  DURATIONS = {
    1 => 30.minutes,
    2 => 2.hours,
    3 => 1.day,
    4 => 1.week
  }.freeze

  MAX_STAGE = 4
  DECAY_PERIOD = 7.days

  def initialize(user)
    @user = user
  end

  def active?
    @user.voting_cooldown_until.present? && @user.voting_cooldown_until > Time.current
  end

  def time_remaining
    return unless active?

    distance_of_time_in_words(Time.current, @user.voting_cooldown_until)
  end

  def apply!(notify: false)
    prev_stage = @user.voting_cooldown_stage
    prev_count = @user.voting_lock_count
    prev_until = @user.voting_cooldown_until
    stage = [ @user.voting_cooldown_stage + 1, MAX_STAGE ].min
    duration = DURATIONS.fetch(stage)
    expires_at = Time.current + duration

    @user.transaction do
      @user.update!(
        voting_cooldown_stage: stage,
        voting_cooldown_until: expires_at,
        voting_lock_count: @user.voting_lock_count + 1
      )
      @user.votes.update_all(suspicious: true)
    end

    audit!("cooldown_applied", {
      voting_cooldown_stage: [ prev_stage, stage ],
      voting_cooldown_until: [ prev_until, expires_at ],
      voting_lock_count: [ prev_count, prev_count + 1 ]
    })

    return unless notify

    @user.dm_user(
      "Hello, thank you for voting, but we noticed that you might not be submitting quality votes. " \
      "As a nudge to keep you on track, you are currently on cooldown for #{duration.inspect}. " \
      "You can vote again after the cooldown expires. Please do note that more low-quality votes will lead to longer cooldowns. " \
      "Flavortown Support will not be able to lift cooldowns, spending time to submit good votes helps everyone :)"
    )
  end

  def clear!
    @user.update!(voting_cooldown_until: nil)
  end

  def record_clean_vote!
    now = Time.current
    @user.update_columns(last_clean_vote_at: now, updated_at: now)
    maybe_decay_stage!(now)
  end

  private

  def maybe_decay_stage!(now)
    return if @user.voting_cooldown_stage.zero? || active?

    expired_at = @user.voting_cooldown_until
    return if expired_at.present? && expired_at > now - DECAY_PERIOD

    clean_since = @user.last_clean_vote_at
    return if clean_since.blank? || clean_since < now - DECAY_PERIOD

    new_stage = @user.voting_cooldown_stage - 1
    old_stage = @user.voting_cooldown_stage
    @user.update_columns(voting_cooldown_stage: new_stage, updated_at: now)
    audit!("cooldown_stage_decayed", { voting_cooldown_stage: [ old_stage, new_stage ] })
  end

  def audit!(event, changes)
    PaperTrail::Version.create!(
      item_type: "User",
      item_id: @user.id,
      event: event,
      whodunnit: "system",
      object_changes: changes
    )
  end
end
