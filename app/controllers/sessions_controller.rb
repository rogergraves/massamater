class SessionsController < ApplicationController
  def new
    redirect_to staff_root_path if staff_logged_in?
  end

  def create
    user = User.find_by(phone: params[:phone])
    if user&.staff? && user.authenticate(params[:password])
      session[:staff_user_id] = user.id
      redirect_to staff_root_path
    else
      flash.now[:alert] = t("auth.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:staff_user_id)
    redirect_to root_path
  end
end
