class ApplicationController < ActionController::Base
  protect_from_forgery
  filter_access_to :all
  helper_method :current_user

  def current_user
  	return unless cookies['session.id']
  	unless @current_user
  		identity = Identity.where("session.id" => cookies['session.id']).first
		@current_user = identity.user if identity
	end

	@current_user
  end
end
