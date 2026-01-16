class AdminConstraint
  def self.matches?(request)
    # otherwise admins who impersonated non admins can't stop
    if request.path == "/admin/users/stop_impersonating" && request.session[:impersonator_user_id].present?
      user = User.find_by(id: request.session[:impersonator_user_id])
    else
      user = admin_user_for(request)
    end

    return false unless user

    policy = AdminPolicy.new(user, :admin)
    # Allow admins, fraud dept, and fulfillment persons (who have limited access)
    policy.access_admin_endpoints? || policy.access_fulfillment_view?
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

class HelperConstraint
  def self.matches?(request)
    u = User.find_by(id: request.session[:user_id])
    u ||= User.find_by(id: ENV["DEV_ADMIN_USER_ID"]) if Rails.env.development?
    u && HelperPolicy.new(u, :helper).access?
  end
end

Rails.application.routes.draw do
  # Static OG images
  get "og/:page", to: "og_images#show", as: :og_image, defaults: { format: :png }
  # Landing
  root "landing#index"
  post "submit_email", to: "landing#submit_email", as: :submit_email
  # get "marketing", to: "landing#marketing"
  get "login", to: redirect("/?login=1")

  # Start Flow
  get  "/start",               to: "start#index"
  post "/start/display_name",  to: "start#update_display_name"
  # post "/start/experience",    to: "start#update_experience"
  post "/start/project",       to: "start#update_project"
  post "/start/prefill_project", to: "start#prefill_project"
  post "/start/devlog",        to: "start#update_devlog"
  post "/start/begin_sign_in", to: "start#begin_sign_in"

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

  # Explore
  get "explore", to: "explore#index", as: :explore_index
  get "explore/gallery", to: "explore#gallery", as: :explore_gallery
  get "explore/following", to: "explore#following", as: :explore_following
  get "explore/extensions", to: "explore#extensions", as: :explore_extensions


  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Test error page for Sentry
  get "test_error" => "debug#error" unless Rails.env.production?

  # Letter opener web for development email preview
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"

    get "og_image_previews", to: "og_image_previews#index"
    get "og_image_previews/*id", to: "og_image_previews#show", as: :og_image_preview
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

  # Leaderboard
  get "leaderboard", to: "leaderboard#index"

  # My
  get "my/balance", to: "my#balance", as: :my_balance
  patch "my/settings", to: "my#update_settings", as: :my_settings
  post "my/roll_api_key", to: "my#roll_api_key", as: :roll_api_key
  post "my/cookie_click", to: "my#cookie_click", as: :my_cookie_click
  get "my/achievements", to: "achievements#index", as: :my_achievements

  # Magic Links
  post "magic_links", to: "magic_links#create"
  get "magic_links/verify", to: "magic_links#verify"

  # This will be an link for people in the slack
  # Not hidden, but wont be shared and only announced in slack
  get "hidden_login", to: "hidden_login#index"

  # API
  namespace :webhooks do
    post "ship_cert", to: "ship_cert#update_status"
  end

  namespace :api do
    get "/", to: "root#index"

    namespace :v1 do
      resources :projects, only: [ :index, :show, :create, :update ] do
        resources :devlogs, only: [ :index, :show ], controller: "project_devlogs"
      end

      resources :docs, only: [ :index ]
      resources :devlogs, only: [ :index, :show ]
      resources :store, only: [ :index, :show ]
      resources :users, only: [ :index, :show ]
    end
  end

  namespace :internal do
    post "revoke", to: "revoke#create"
  end

  namespace :user, path: "" do
    resources :tutorial_steps, only: [ :show ]
  end

  namespace :helper, constraints: HelperConstraint do
    root to: "application#index"
    resources :users, only: [ :index, :show ]
    resources :projects, only: [ :index, :show ] do
      member do
        post :restore
      end
    end
    resources :shop_orders, only: [ :index, :show ]
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

    resources :users, only: [ :index, :show, :update ], shallow: true do
       member do
         post :promote_role
         post :demote_role
         post :toggle_flipper
         post :sync_hackatime
         post :mass_reject_orders
         post :adjust_balance
         post :ban
         post :unban
         post :cancel_all_hcb_grants
         post :shadow_ban
         post :unshadow_ban
         post :impersonate
         post :refresh_verification
       end
       collection do
         post :stop_impersonating
       end
       resource :magic_link, only: [ :show ]
     end
    resources :projects, only: [ :index, :show ], shallow: true do
      member do
        post :restore
      end
    end
    get "user-perms", to: "users#user_perms"
    get "manage-shop", to: "shop#index"
    post "shop/clear-carousel-cache", to: "shop#clear_carousel_cache", as: :clear_carousel_cache
    resources :shop_items, only: [ :new, :create, :show, :edit, :update, :destroy ] do
      collection do
        post :preview_markdown
      end
    end
    resources :shop_orders, only: [ :index, :show ] do
      member do
        post :reveal_address
        post :approve
        post :reject
        post :place_on_hold
        post :release_from_hold
        post :mark_fulfilled
        post :update_internal_notes
        post :assign_user
        post :cancel_hcb_grant
        post :refresh_verification
      end
    end
    resources :audit_logs, only: [ :index, :show ]
    resources :reports, only: [ :index, :show ] do
      collection do
        post :process_demo_broken
      end
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
    resources :devlogs, only: %i[new create edit update destroy], module: :project, shallow: false do
      member do
        get :versions
      end
    end
    resources :reports, only: [ :create ], module: :project
    resource :og_image, only: [ :show ], module: :projects, defaults: { format: :png }
    member do
      get :ship
      get :readme
      patch :update_ship
      post :submit_ship
      post :mark_fire
      post :unmark_fire
      post :follow
      delete :unfollow
      post :resend_webhook
      post :request_recertification
    end
  end

  # Devlog likes and comments
  resources :devlogs, only: [] do
    resource :like, only: [ :create, :destroy ]
    resources :comments, only: [ :create, :destroy ]
  end

  # Public user profiles
  resources :users, only: [ :show ] do
    resource :og_image, only: [ :show ], module: :users, defaults: { format: :png }
  end
end
