RailsAdmin.config do |config|

  ### Popular gems integration

  ## == Devise ==
  # Настраиваем авторизацию в админке с помощью devise
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method(&:current_user)

  RailsAdmin.config do |config|
    config.authorize_with do
      redirect_to main_app.root_path unless current_user.is_admin?
    end
  end

  config.included_models = ['Question', 'Game', 'User']
end
