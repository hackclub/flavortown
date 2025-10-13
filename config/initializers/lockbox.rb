Lockbox.master_key =
  if Rails.env.test?
    "0" * 64
  else
    Rails.application.credentials.dig(:lockbox, :master_key)
  end
