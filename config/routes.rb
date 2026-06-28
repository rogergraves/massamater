Rails.application.routes.draw do
  root "pages#home"

  get    "/login",  to: "sessions#new",     as: :login
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy", as: :logout

  patch "/locale", to: "locales#update", as: :locale

  namespace :staff do
    root "dashboard#index"
  end
end
