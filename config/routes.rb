Rails.application.routes.draw do
  root "pages#home"

  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  patch "/locale", to: "locales#update", as: :locale

  namespace :staff do
    root "dashboard#index"
    resources :inventory,            only: [:index, :create, :update, :destroy]
    resources :inventory_exceptions, only: [:create, :destroy]
    resource  :store_hours,          only: [:edit, :update]
    resources :store_exceptions,     only: [:create, :destroy]
  end
end
