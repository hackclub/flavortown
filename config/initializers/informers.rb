Rails.application.config.after_initialize do
  if defined?(Informers) && !Rails.env.test?
    Rails.logger.info("[Informers] Preloading embedding model...")
    ProjectSearchService.warmup
  end
end
