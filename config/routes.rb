class AdminConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    return false unless user
    user&.can_use_admin_endpoints
  end
end

Rails.application.routes.draw do
  # Landing
  root "landing#index"

  # RSVPs
  resources :rsvps, only: [ :create ]

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
  # admin shallow routing
  namespace :admin do
    root to: "application#index"

    mount Blazer::Engine, at: "blazer", constraints: ->(request) {
      user = User.find_by(id: request.session[:user_id])
      user && AdminPolicy.new(user, :admin).blazer?
    }

    mount Flipper::UI.app(Flipper), at: "flipper", constraints: ->(request) {
      user = User.find_by(id: request.session[:user_id])
      user && AdminPolicy.new(user, :admin).flipper?
    }

    mount MissionControl::Jobs::Engine, at: "jobs", constraints: ->(request) {
      user = User.find_by(id: request.session[:user_id])
      user && AdminPolicy.new(user, :admin).access_admin_endpoints?
    }

    resources :users, only: [ :index, :show ], shallow: true do
      member do
        post :promote_role
        post :demote_role
      end
    end
    resources :projects, only: [ :index ], shallow: true
    get "user-perms", to: "users#user_perms"
    get "manage-shop", to: "shop#index"
    post "shop/clear-carousel-cache", to: "shop#clear_carousel_cache", as: :clear_carousel_cache
    resources :shop_items, only: [ :new, :create, :show, :edit, :update, :destroy ]
  end

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
