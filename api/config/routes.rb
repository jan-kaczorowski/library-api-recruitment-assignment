Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  scope :api do
    resources :book_copies, only: %i[index create show update destroy] do
      # POST /book_copies/:book_copy_id/loans  -> loans#create
      resources :loans, only: :create
    end

    resources :loans, only: %i[index]

    resources :readers, only: %i[index create]

    # PUT /loans/:id/return  -> loans#return_book
    put "loans/:id/return", to: "loans#return_book", as: :return_loan
  end
end
