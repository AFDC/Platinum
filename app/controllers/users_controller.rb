class UsersController < ApplicationController
	before_filter :load_user_from_params, only: [:show, :edit_avatar, ]
	filter_access_to [:edit_avatar, :update_avatar, :destroy_avatar], :attribute_check => true

	def index
		@user_list = []
		if (params[:query])
			@user_list = user_search(params[:query])
		end
	end

	def search
		respond_to do |format|
			format.json do
				results = { :suggestions => [], :data => [], :query => params[:query] }
				user_search(params[:query]).each do |user|
					results[:suggestions] << "#{user.firstname} #{user.lastname} [#{user.email_address}]"
					results[:data] << {
						'_id' => user._id,
						'firstname' => user.firstname,
						'lastname' => user.lastname,
						'email_address' => user.email_address,
					}
				end
				render :json => results
			end
		end
	end

	def show
	end

	def new
		if current_user
			redirect_to users_path, flash: {error: "You are already logged in!"}
		else
			@user = User.new
		end
	end

	def create
		@user = User.new(user_params)

		if @user.save
			redirect_to "/auth/resetPassword/#{@user.email_address}", notice: 'You have successfully created a user account and a password has been emailed to you.'
		else
			render :action => 'new'
		end
	end

	def edit_avatar
	end

	def update_avatar
		@user.update_attributes(user_params)
		redirect_to edit_avatar_user_path(@user), notice: 'New profile pic uploaded!'
	end

	def destroy_avatar
		@user.avatar = nil
		@user.save
		redirect_to edit_avatar_user_path(@user), notice: 'Profile pic removed'
	end

	private

	def user_params
		permitted_params = [
			:gender, :firstname, :lastname, :email_address, :birthdate, 
			:avatar,
			:middlename, :address, :city, :state, :postal_code, :height, :weight,
			:occupation
		]

		params.require(:user).permit(*permitted_params)
	end

	def user_search(query)
		name_search = {"$and" => []}
		query.chomp.split(/\W+/).each do |q|
			name_search['$and'] << { "$or" => [
				{firstname: /#{q}/i},
				{lastname: /#{q}/i}
			]}
		end

		User.any_of([{email_address: /#{query}/i}, name_search])
	end

	def load_user_from_params
		begin
			@user = User.find(params[:id])
		rescue
			redirect_to users_path, flash: {error: "Could not load user for ID '#{params[:id]}', please try a different user."}
		end
	end
end
