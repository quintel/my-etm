require 'sidekiq/web'

Rails.application.routes.draw do
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

  resources :saved_scenarios do
    resource :feature, only: %i[show create update destroy], controller: 'featured_scenarios' do
      get :confirm_destroy
    end

    member do
      put :publish
      put :unpublish
      put :discard
      put :undiscard
      get :confirm_destroy
    end
  end

  get :discarded, to: 'discarded#index'

  namespace :admin do
    get '/', to: redirect('/admin/org')
    get 'org',              to: 'users#org'
    get 'users',            to: 'users#all'
    get 'user/:user_id',         to: 'users#edit',    as: :edit_user
    put 'user/:user_id',         to: 'users#update',  as: :update_user
    put 'user/:user_id/confirm', to: 'users#confirm', as: :confirm_user

    get 'scenarios', to: 'saved_scenarios#index'

    get 'applications', to: 'staff_applications#index'
    put 'applications', to: 'staff_applications#update'
  end

  get :contact, to: 'static_pages#contact'
  post :send_message, to: 'static_pages#send_message'
  get :privacy, to: 'static_pages#privacy'
  get :terms,   to: 'static_pages#terms'
  get :root,    to: 'static_pages#empty'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end
