class UsersController < ApplicationController
	before_filter :load_user_from_params, only: [:show, :edit_avatar, :registrations, :edit, :update, :login_as]
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

	def login_as
		session['real_user_id'] = current_user._id.to_s
		session['user_id'] = @user._id.to_s

		redirect_to home_path, notice: "You are now logged in as #{@user.name}, log out to return to your old credentials"
	end

	def registrations
		@registrations = Registration.where(user_id: @user._id).desc(:signup_timestamp)
	end

	def show
	end

	def new
		if current_user
			redirect_to home_path, flash: {error: "You are already logged in!"}
		else
			@user = User.new
		end
	end

	def create
		@user = User.new(user_params)

		if @user.save
			MailChimpWorker.perform_async(@user._id.to_s, params[:subscribe])
			redirect_to '/', notice: 'You have successfully created a new user account.'
		else
			render :action => 'new'
		end
	end

	def update
		filtered_params = user_params

		editable_perms = {
			admin: :perm_admin, 
			:"steering-committee" => :perm_steering_committee,
			:"league-manager" => :perm_league_manager, 
			:"covid-admin" => :perm_covid_admin
		}
		if permitted_to? :edit_permissions, @user
			new_perms = []
			@user.role_symbols.each do |role|
				if (editable_perms.keys.include?(role) == false)
					new_perms << role
				end
			end

			editable_perms.keys.each do |role|
				field_name = editable_perms[role]
				if params[field_name]
					new_perms << role
				end
			end

			filtered_params[:permission_groups] = new_perms
		end


		if @user.update_attributes(filtered_params)
			MailChimpWorker.perform_async(@user._id.to_s, params[:subscribe])
			redirect_to user_path(@user), notice: "User Updated Successfully"
		else
			render :edit
		end
	end

	def edit_avatar
	end

	def update_avatar
		@user.attributes = params.require(:user).permit(:avatar)
		@user.save(validate: false)

		redirect_to edit_avatar_user_path(@user), notice: 'New profile pic uploaded!'
	end

	def destroy_avatar
		@user.avatar = nil
		@user.save(validate: false)
		redirect_to edit_avatar_user_path(@user), notice: 'Profile pic removed'
	end

	private

	def user_params
		permitted_params = [
			:gender, :firstname, :lastname, :email_address, :birthdate,
			:avatar, :handedness,
			:middlename, :address, :city, :state, :postal_code, :height, :weight,
			:occupation, :password, :password_confirmation
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
		@user = User.find(params[:id])

		unless @user
			redirect_to users_path, flash: {error: "Could not load user for ID '#{params[:id]}', please try a different user."}
		end
	end
end
