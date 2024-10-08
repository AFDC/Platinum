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

  def log_audit(action, details = {})
    details[:acting_user] = current_user unless details.key?(:acting_user)
    details[:action] = action

    AuditLog.create(details)
  end

  protected

  def permission_denied
    if current_user
      if request.format.json?
        render json: { error: "Sorry, you are not allowed to access that page." }, status: :forbidden
      else
        flash[:error] = "Sorry, you are not allowed to access that page."
        redirect_to home_url and return
      end
    else
      if request.format.json?
        render json: { error: "Please log in to view that page." }, status: :unauthorized
      else
        flash[:error] = "Please log in to view that page."
        session[:login_redirect_url] = request.original_url
        redirect_to auth_path and return
      end
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
