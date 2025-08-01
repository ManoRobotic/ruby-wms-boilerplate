Rails.application.routes.draw do
  root "home#index"

  # Health checks (should be at the top for monitoring)
  get "/health", to: "health#check"
  get "/health/liveness", to: "health#liveness"
  get "/health/readiness", to: "health#readiness"

  devise_for :admins, controllers: {
    registrations: "admin/registrations"
  }

  authenticate :admin do
    root to: "admin#index", as: :admin_root
  end

  namespace :admin do
    # WMS Resources
    resources :warehouses do
      resources :waves do
        member do
          patch :release
          patch :start  
          patch :complete
          patch :cancel
        end
        collection do
          post :auto_create
          get :suggestions
        end
      end
      
      resources :zones do
        resources :locations do
          member do
            get :cycle_count
            post :create_cycle_count
          end
        end
      end
    end

    resources :tasks do
      member do
        patch :assign
        patch :start
        patch :complete
        patch :cancel
      end
      collection do
        patch :bulk_assign
      end
    end

    resources :pick_lists do
      member do
        patch :assign
        patch :start
        patch :complete
        patch :cancel
        patch :optimize_route
      end
      collection do
        post :generate_for_order
      end
    end

    resources :inventory_transactions, only: [ :index, :show, :new, :create, :destroy ] do
      collection do
        get :movement_report
        get :daily_summary
        get :quick_adjustment
        post :create_adjustment
      end
    end

    resources :receipts do
      member do
        patch :start_receiving
        patch :complete
      end
      resources :receipt_items, only: [ :show, :edit, :update ]
    end

    resources :cycle_counts do
      member do
        patch :start
        patch :complete
      end
      resources :cycle_count_items, only: [ :show, :edit, :update ]
    end

    resources :shipments do
      member do
        patch :ship
        patch :deliver
      end
    end

    # Original resources
    resources :orders do
      member do
        patch :allocate_inventory
        patch :pack
        patch :ship
        patch :cancel
      end
    end
    resources :categories
    resources :products do
      resources :stocks
    end
    
    # Manual Printing
    get 'manual_printing', to: 'manual_printing#index'
    post 'manual_printing/connect_printer', to: 'manual_printing#connect_printer'
    post 'manual_printing/print_test', to: 'manual_printing#print_test'
    post 'manual_printing/calibrate_sensor', to: 'manual_printing#calibrate_sensor'
    post 'manual_printing/printer_status', to: 'manual_printing#printer_status'
    
    # Scale Reading
    post 'manual_printing/connect_scale', to: 'manual_printing#connect_scale'
    post 'manual_printing/read_weight', to: 'manual_printing#read_weight'
  end

  resources :categories, only: [ :show ]

  get "admin" => "admin#index"
  get "cart" => "cart#show"
  get "precios", to: "prices#index"


  post "webhooks/mercadopago" => "webhooks#mercadopago"

  post "/checkout", to: "checkouts#create"
  get "/checkout/success", to: "checkouts#success"
  get "/checkout/failure", to: "checkouts#failure"
  get "/checkout/pending", to: "checkouts#pending"

  resources :products, only: [ :show ]
  resources :templates
end
