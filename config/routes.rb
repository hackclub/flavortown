class AdminConstraint
  def self.matches?(request)
    user = admin_user_for(request)
    return false unless user
    AdminPolicy.new(user, :admin).access_admin_endpoints?
  end

  def self.admin_user_for(request)
    user = User.find_by(id: request.session[:user_id])
    return user if user

    if Rails.env.development? && ENV["DEV_ADMIN_USER_ID"].present?
      User.find_by(id: ENV["DEV_ADMIN_USER_ID"])
    end
  end

  def self.allow?(request, permission)
    user = admin_user_for(request)
    user && AdminPolicy.new(user, :admin).public_send(permission)
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
  delete "shop/cancel_order/:order_id", to: "shop#cancel_order", as: :cancel_shop_order
  get "shop/order", to: "shop#order"
  post "shop/order", to: "shop#create_order"
  patch "shop/update_region", to: "shop#update_region"

  # Voting
  resources :votes, only: [ :new, :create, :index ]

  # Reports
  resources :reports, only: [ :create ]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Test error page for Sentry
  get "test_error" => "debug#error" unless Rails.env.production?

  # Letter opener web for development email preview
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Action Mailbox for incoming HCB and tracking emails
  mount ActionMailbox::Engine => "/rails/action_mailbox"
  mount ActiveInsights::Engine => "/insights"
  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # hackatime should not create a new session; it's used for linking
  get "auth/hackatime/callback", to: "identities#hackatime"

  # Sessions
  get "auth/:provider/callback", to: "sessions#create"
  get "/auth/failure", to: "sessions#failure"
  delete "logout", to: "sessions#destroy"

  # OAuth callback for HCA
  get "/oauth/callback", to: "sessions#create"

  # Kitchen
  get "kitchen", to: "kitchen#index"

  # My
  get "my/balance", to: "my#balance"
  patch "my/settings", to: "my#update_settings", as: :my_settings

  # Magic Links
  post "magic_links", to: "magic_links#create"
  get "magic_links/verify", to: "magic_links#verify"

  # API
  namespace :api do
    get "/", to: "root#index"

    resources :projects
    resources :store
  end

  namespace :user, path: "" do
    resources :tutorial_steps, only: [ :show ]
  end

  # admin shallow routing
  namespace :admin, constraints: AdminConstraint do
    root to: "application#index"

    mount Blazer::Engine, at: "blazer", constraints: ->(request) {
      AdminConstraint.allow?(request, :access_blazer?)
    }

    mount Flipper::UI.app(Flipper), at: "flipper", constraints: ->(request) {
      AdminConstraint.allow?(request, :access_flipper?)
    }

    mount MissionControl::Jobs::Engine, at: "jobs", constraints: ->(request) {
      AdminConstraint.allow?(request, :access_jobs?)
    }

    resources :users, only: [ :index, :show ], shallow: true do
       member do
         post :promote_role
         post :demote_role
         post :toggle_flipper
         post :sync_hackatime
         post :mass_reject_orders
         post :adjust_balance
         post :ban
         post :unban
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
        post :mark_fulfilled
        post :update_internal_notes
      end
    end
    resources :audit_logs, only: [ :index, :show ]
    resources :reports, only: [ :index, :show ] do
      member do
        post :review
        post :dismiss
      end
    end
    get "payouts_dashboard", to: "payouts_dashboard#index"
    resources :fulfillment_dashboard, only: [ :index ] do
      collection do
        post :send_letter_mail
      end
    end
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
    member do
      get :ship
      patch :update_ship
      post :submit_ship
    end
  end
end
