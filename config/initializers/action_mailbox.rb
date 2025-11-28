Rails.application.config.after_initialize do
  Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/mailboxes"))
end
