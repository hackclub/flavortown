# Bullet 8.1.0 does not clear :bullet_call_stacks in end_request,
# leaving the last request's backtraces (one per tracked AR object)
# pinned in memory until the next request overwrites them.
#
# In production with deep middleware stacks (~344 frames) and many
# tracked objects (~47K per thread), this retains ~5-6 GB per Puma
# thread in backtrace strings alone.
if defined?(Bullet)
  module BulletMonkeyPatch
    def end_request
      super
      Thread.current.thread_variable_set(:bullet_call_stacks, nil)
    end
  end
  Bullet.singleton_class.prepend(BulletMonkeyPatch)
end
