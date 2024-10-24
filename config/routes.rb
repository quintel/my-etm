require 'sidekiq/web'

Rails.application.routes.draw do
  resources :saved_scenarios do
    member do
      put :publish
      put :unpublish
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  use_doorkeeper
  use_doorkeeper_openid_connect

  devise_for :users, path: 'identity', sign_out_via: %i[get post delete], controllers: {
    sessions: 'users/sessions',
    registrations: 'users/registrations'
  }

  authenticate :user, lambda { |u| u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  namespace :identity do
    get '/', to: redirect('/identity/profile')
    get 'profile', to: 'settings#index', as: :profile

    get 'change_name', to: 'settings#edit_name', as: :edit_name
    post 'change_name', to: 'settings#update_name'

    get 'change_email', to: 'settings#edit_email', as: :edit_email
    post 'change_email', to: 'settings#update_email'

    get 'change_password', to: 'settings#edit_password', as: :edit_password
    post 'change_password', to: 'settings#update_password'

    post 'change_scenario_privacy', to: 'settings#update_scenario_privacy'

    get 'newsletter', to: 'newsletter#edit', as: :edit_newsletter
    post 'newsletter', to: 'newsletter#update'

    resources :tokens, only: [:index, :new, :create, :destroy], as: :tokens
    resources :authorized_applications, only: [:index], as: :authorized_applications
  end

  devise_scope :user do
    get 'identity/delete_account', to: 'users/registrations#confirm_destroy', as: :delete_account
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end
