class ApplicationController < ActionController::Base
  protect_from_forgery
  filter_access_to :all
  helper_method :current_user

  def current_user
  	return unless cookies['session.id']
  	@current_user ||= Identity.where("session.id" => cookies['session.id']).first.user
  end
end
