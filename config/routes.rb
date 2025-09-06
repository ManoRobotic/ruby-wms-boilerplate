Rails.application.routes.draw do
  # ActionCable WebSocket endpoint
  mount ActionCable.server => '/cable'
  devise_for :users
  root "home#index"

  # Health checks (should be at the top for monitoring)
  get "/health", to: "health#check"
  get "/health/liveness", to: "health#liveness"
  get "/health/readiness", to: "health#readiness"

  devise_for :admins, controllers: {
    registrations: "admin/registrations",
    sessions: "admin/sessions"
  }

  authenticate :admin do
    root to: "admin#index", as: :admin_root
  end

  namespace :admin do
    # Production Orders
    resources :production_orders do
      member do
        patch :start
        patch :pause
        patch :complete
        patch :cancel
        get :print_bag_format
        get :print_box_format
        get :print_consecutivos
        patch :update_weight
        get :modal_details
        post :toggle_selection
      end
      collection do
        post :weigh_item
        post :test_broadcast
        post :sync_excel_data
        post :sync_google_sheets_opro
        post :print_selected
        post :bulk_toggle_selection
        get :selected_orders_data
        delete :clear_all_selections
      end
      
      # Nested routes for production order items (consecutivos/folios)
      resources :production_order_items, path: "items" do
        collection do
          patch :mark_as_printed
        end
      end
    end

    # Barcode scanning
    get "production_orders/scan_barcode", to: "production_orders#scan_barcode_page"
    post "production_orders/scan_barcode", to: "production_orders#scan_barcode"
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
        member do
          get :locations
        end
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

    # User management
    resources :users do
      member do
        patch :activate
        patch :deactivate
      end
    end

    # Original resources
    resources :orders do
      member do
        patch :allocate_inventory
        patch :pack
        patch :ship
        patch :cancel
        patch :mark_delivered
      end
    end
    resources :categories
    resources :products do
      resources :stocks
    end

    # Notifications
    resources :notifications, only: [ :index, :show, :destroy ] do
      member do
        patch :mark_read
      end
      collection do
        post :mark_all_read
        get :poll
        get :poll_immediate
      end
    end

    # Manual Printing
    get "manual_printing", to: "manual_printing#index"
    post "manual_printing/connect_printer", to: "manual_printing#connect_printer"
    post "manual_printing/print_test", to: "manual_printing#print_test"
    post "manual_printing/calibrate_sensor", to: "manual_printing#calibrate_sensor"
    post "manual_printing/printer_status", to: "manual_printing#printer_status"

    # Scale Reading
    post "manual_printing/connect_scale", to: "manual_printing#connect_scale"
    post "manual_printing/read_weight", to: "manual_printing#read_weight"

    # Configurations
    get "configurations", to: "configurations#show"
    get "configurations/edit", to: "configurations#edit"
    patch "configurations", to: "configurations#update"
    post "configurations/test_connection", to: "configurations#test_connection"
    post "configurations/check_changes", to: "configurations#check_changes"
    post "configurations/sync_now", to: "configurations#sync_now"
    post "configurations/incremental_sync", to: "configurations#incremental_sync"

    # Inventory Codes
    resources :inventory_codes do
      collection do
        post :import_excel
        get :export_excel
        get :selected_data
        post :toggle_selection
        delete :clear_selection
      end
    end
  end

  resources :categories, only: [ :show ]

  get "admin" => "admin#index"
  get "cart" => "cart#show"
  get "precios", to: "prices#index"


  post "webhooks/mercadopago" => "webhooks#mercadopago"

  # API routes for serial communication
  namespace :api do
    resources :serial, only: [] do
      collection do
        get :health
        get :ports
        post :connect_scale
        post :disconnect_scale
        post :start_scale
        post :stop_scale
        get :read_weight
        get :last_reading
        get :latest_readings
        get :get_weight_now
        post :connect_printer
        post :print_label
        post :test_printer
        post :disconnect_printer
      end
    end
    # New API route for production orders
    resources :production_orders, only: [:create]
  end

  post "/checkout", to: "checkouts#create"
  get "/checkout/success", to: "checkouts#success"
  get "/checkout/failure", to: "checkouts#failure"
  get "/checkout/pending", to: "checkouts#pending"

  resources :products, only: [ :show ]
  resources :templates
  
  # Test page for serial system
  get '/test_serial', to: proc { |env| [200, {}, [File.read(Rails.root.join('test_serial_system.html'))]] }
end
