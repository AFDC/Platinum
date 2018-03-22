class ApplicationController < ActionController::Base
  protect_from_forgery
  filter_access_to :all
  helper_method :current_user
  before_bugsnag_notify :add_user_info_to_bugsnag

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

  def audit(action, target, details = {})
    details[:acting_user] = current_user unless details.key?(:acting_user)

    AuditLog.log(action, target, details)
  end

  protected

  def permission_denied
    if current_user
      flash[:error] = "Sorry, you are not allowed to access that page."
      redirect_to home_url and return
    else
      flash[:error] = "Please log in to view that page."
      session[:login_redirect_url] = request.original_url
      redirect_to auth_path and return
    end
  end

  private

  def add_user_info_to_bugsnag(report)
    return if current_user.nil?
    report.user = {
      email: current_user.email_address,
      name: current_user.name,
      id: current_user._id
    }
  end
end
