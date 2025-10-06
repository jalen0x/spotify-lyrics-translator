Rails.application.routes.draw do
  post "translate", to: "translate#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
