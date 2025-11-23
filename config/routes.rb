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
  get "login", to: redirect("/?login=1")

  # RSVPs
  resources :rsvps, only: [ :create ]

  # Shop
  get "shop", to: "shop#index"
  get "shop/my_orders", to: "shop#my_orders"

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

  # hackatime should not create a new session; it's used for linking
  get "auth/hackatime/callback", to: "identities#hackatime"

  # Sessions
  get "auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  get "logout", to: "sessions#destroy"

  # OAuth callback for HCA
  get "/oauth/callback", to: "sessions#create"

  # Kitchen
  get "kitchen", to: "kitchen#index"

  # Magic Links
  post "magic_links", to: "magic_links#create"
  get "magic_links/verify", to: "magic_links#verify"
  # admin shallow routing
  namespace :admin, constraints: AdminConstraint do
    root to: "application#index"

    mount Blazer::Engine, at: "blazer", constraints: ->(request) {
      user = User.find_by(id: request.session[:user_id])
      if user.nil? && !Rails.env.production?
        user_id = request.session[:test_user_id] || 1
        user = User.find_by(id: user_id) || User.first
      end
      user && AdminPolicy.new(user, :admin).access_blazer?
    }

    mount Flipper::UI.app(Flipper), at: "flipper", constraints: ->(request) {
      user = User.find_by(id: request.session[:user_id])
      if user.nil? && !Rails.env.production?
        user_id = request.session[:test_user_id] || 1
        user = User.find_by(id: user_id) || User.first
      end
      user && AdminPolicy.new(user, :admin).access_flipper?
    }

    mount MissionControl::Jobs::Engine, at: "jobs", constraints: ->(request) {
      user = User.find_by(id: request.session[:user_id])
      if user.nil? && !Rails.env.production?
        user_id = request.session[:test_user_id] || 1
        user = User.find_by(id: user_id) || User.first
      end
      user && AdminPolicy.new(user, :admin).access_admin_endpoints?
    }

    resources :users, only: [ :index, :show ], shallow: true do
       member do
         post :promote_role
         post :demote_role
         post :toggle_flipper
         post :sync_hackatime
       end
       resource :magic_link, only: [ :show ]
     end
    resources :projects, only: [ :index ], shallow: true
    get "user-perms", to: "users#user_perms"
    get "manage-shop", to: "shop#index"
    post "shop/clear-carousel-cache", to: "shop#clear_carousel_cache", as: :clear_carousel_cache
    resources :shop_items, only: [ :new, :create, :show, :edit, :update, :destroy ]
    resources :shop_orders, only: [ :index, :show ] do
      member do
        post :reveal_address
        post :approve
        post :reject
        post :place_on_hold
        post :release_from_hold
      end
    end
    resources :audit_logs, only: [ :index, :show ]
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
    resources :devlogs, only: [ :new, :create ], module: :project
  end
end
