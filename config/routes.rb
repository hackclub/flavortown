Rails.application.routes.draw do
  # Landing
  root "landing#index"
  
  # RSVPs
  resources :rsvps, only: [:create]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Letter opener web for development email preview
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Sessions
  get "auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  get "logout", to: "sessions#destroy"

  # Project Ideas
  resources :project_ideas, only: [] do
    collection do
      post :random
    end
  end

  # Projects
  resources :projects, shallow: true do
    resources :memberships, only: [ :create, :destroy ], module: :project
  end
end
