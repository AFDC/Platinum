require 'sidekiq/web'

Platinum::Application.routes.draw do
  match '/users/search' => 'users#search', via: :get
  resources :fields, :waivers, :schedules, :comp_groups, :payments, :spirit_reports

  resources :waivers do
    member do
      get 'sign_waiver'
      post 'sign_waiver'
      get 'signatures'
    end
    resources :signatures, only: [:show], controller: 'waiver_signatures'
  end

  resources :invitations do
    member do
      get 'accept'
      get 'decline'
      get 'cancel'
    end
  end

  resources :payments do
    collection do
      post 'pre_authorize'
    end
  end

  resources :registrations do
    member do
      put 'cancel'
      get 'donate'
      get 'pay'
      get 'waitlist_authorize'
    end
  end

  resources :leagues do
    member do
      get 'cachekey'
      get 'register'
      get 'registrations'
      post 'registrations'

      get 'volunteer_to_pickup'
      post 'volunteer_to_pickup'
      get 'pickup_list'
      get 'invite_pickup'
      post 'invite_pickup'
      get 'pickup_registration'
      post 'pickup_registration'
      get 'pay_pickup'
      
      get 'players'
      get 'reg_list'
      get 'team_list'
      post 'cancel_registration'
      post 'promote_waitlisted_registration'
      post 'add_player_to_team'

      post 'update_invites'

      get 'manage_roster'
      post 'upload_roster'
      get 'setup_roster_import'
      post 'import_roster'
      
      get 'setup_schedule_import'
      post 'upload_schedule'
      post 'import_schedule'
      delete 'remove_future_games'

      get 'rainout_games'
      post 'process_rainout'

      get 'invite_pair'
      get 'leave_pair'

      get 'missing_spirit_reports'
      get 'show_attendance'

      get 'finances'
    end

    resources :teams, only: [:new, :create]
    resources :registration_groups do
      post 'invite_players'

      member do
        put 'add_to_team'
      end
    end
  end

  resources :teams, except: [:new, :create] do
    member do
      get 'show_attendance'
      get 'manage_attendance'
      put 'update_attendance'
    end
    resources :attendances, only: [:show, :create, :update, :destroy]
  end


  resources :games do
    member do
      get 'edit_score'
      put 'update_score'
    end
  end

  resources :users do
    resources :notification_methods do
      member do
        get 'enter_confirmation'
        post 'confirm'
        get 'confirm'
      end
    end
    member do
      get 'registrations'
      get 'edit_avatar'
      put 'update_avatar'
      delete 'destroy_avatar'
      get 'login_as'
    end
  end

# COVID
  get 'covid', to: 'covid#index'
  post 'covid', to: 'covid#confirm_vax_status'

  get 'help/login', to: 'help#login', as: 'login_help'
  get 'help/registration', to: 'help#registration', as: 'registration_help'
  get 'toc', to: 'help#toc', as: 'terms_and_conditions'
  get 'privacy', to: 'help#privacy', as: 'privacy_policy'

  get 'profile', to: 'profile#index', as: 'user_profile'
  get 'profile/edit', to: 'profile#edit', as: 'edit_user_profile'
  get 'profile/gRank', to: 'profile#edit_g_rank', as: 'edit_g_rank_profile'
  put 'profile/gRank', to: 'profile#update_g_rank', as: 'update_g_rank_profile'

  get 'login', to: 'auth#index', as: 'auth'
  post 'login', to: 'auth#login', as: 'login'
  get 'logout', to: 'auth#logout', as: 'logout'
  get 'reset-password', to: 'auth#forgot_password', as: 'forgot_password'
  post 'reset-password', to: 'auth#reset_password', as: 'reset_password'

  get 'logs', to: 'dashboard#audit_logs'
  root to: 'dashboard#homepage', as: 'home'
end
