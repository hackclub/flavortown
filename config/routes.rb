class AdminConstraint
  def self.matches?(request)
    return false unless request.session[:user_id]

    user = User.find_by(id: request.session[:user_id])
    return false unless user
    user&.can_use_admin_endpoints
  end
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

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
  
    resources :users, shallow: true
  end

  # Projects

  resources :projects, except: :index, shallow: true do
    resources :memberships, only: [ :create, :destroy ], module: :project
  end

  # Landing
  root "landing#index"
end
