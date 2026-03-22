Rails.application.routes.draw do
  root "dashboard#index"

  resources :entries do
    member do
      post :reprocess
    end
  end

  resources :tags, only: [:index, :show]

  get "search", to: "search#index", as: :search
  post "search/ask", to: "search#ask", as: :ask_search

  get "up" => "rails/health#show", as: :rails_health_check
end
