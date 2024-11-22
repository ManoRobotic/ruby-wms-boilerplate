Rails.application.routes.draw do
  root "home#index"

  devise_for :admins, controllers: {
    registrations: "admin/registrations"
  }

  authenticate :admin_user do
    root to: "admin#index", as: :admin_root
  end

  namespace :admin do
    resources :orders
    resources :categories
      resources :products do
        resources :stocks
      end
  end

  resources :categories, only: [:show]

  get "admin" => "admin#index"
  get 'precios', to: 'precios#index'
end
