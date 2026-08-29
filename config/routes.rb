Rails.application.routes.draw do
  root "pages#home"

  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  patch "/locale", to: "locales#update", as: :locale

  namespace :staff do
    root "dashboard#index"
    resources :inventory,            only: [:index, :create, :update, :destroy]
    resource  :store_hours,          only: [:edit, :update]
    resources :store_exceptions,     only: [:create, :destroy]
    resources :orders, only: [:new, :create, :edit, :update, :destroy] do
      collection { get :products }
      member do
        patch :collect
        patch :uncollect
      end
    end
    get "customers/lookup", to: "customers#lookup", as: :customer_lookup
  end
end
