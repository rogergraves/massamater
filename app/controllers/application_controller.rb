class ApplicationController < ActionController::Base
  helper_method :current_staff_user, :staff_logged_in?

  before_action :set_locale

  private

  def current_staff_user
    @current_staff_user ||= User.find_by(id: session[:staff_user_id])
  end

  def staff_logged_in?
    current_staff_user.present?
  end

  def require_staff!
    unless staff_logged_in?
      redirect_to login_path, alert: t("auth.login_required")
    end
  end

  def set_locale
    locale = session[:locale]&.to_sym
    I18n.locale = I18n.available_locales.include?(locale) ? locale : I18n.default_locale
  end
end
