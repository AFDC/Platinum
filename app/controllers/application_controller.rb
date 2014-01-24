class ApplicationController < ActionController::Base
  protect_from_forgery
  filter_access_to :all
  helper_method :current_user

  def current_user
    unless @current_user
      if session[:user_id]
        @current_user = User.find(session[:user_id])
      elsif cookies[:platinum_login]
        cookie_val = cookies[:platinum_login]
        @current_user = User.where({remember_me_cookie: cookie_val}).first
        session[:user_id] = @current_user._id if @current_user
      end
    end

    @current_user
  end
end
