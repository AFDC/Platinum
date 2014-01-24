class AuthController < ApplicationController
    before_filter :load_user_from_params, only: [:login, :reset_password]
    before_filter :restrict_logged_in, only: [:index, :login]

    def login
        unless @user
            redirect_to auth_path, flash: {error: 'User not found for that email address.'} and return
        end

        unless @user.password_digest
            redirect_to forgot_password_path, flash: {error: 'It looks like we don\'t have a password on file for you. Please perform a password reset.'} and return
        end

        unless @user.authenticate(params[:password])
           redirect_to auth_path, flash: {error: 'That password does not match what we have on file.'} and return 
        end

        session[:user_id] = @user._id

        if params[:remember_me]
            @user.remember_me_cookie = SecureRandom.hex(32)
            cookies[:platinum_login] = @user.remember_me_cookie
        else
            @user.remember_me_cookie = nil
        end

        @user.save

        redirect_to auth_path, notice: 'YOU HAVE BEEN LOGGED IN!'         
    end

    def reset_password
        unless @user
            redirect_to forgot_password_path, flash: {error: 'User not found for that email address.'} and return
        end

        new_pw = @user.reset_password
        @user.save

        redirect_to auth_path, notice: "Please check your email for a password reset. #{new_pw}"
    end

    def logout
        @user = current_user
        @user.remember_me_cookie = nil
        @user.save

        cookies.delete(:platinum_login)

        reset_session

        redirect_to "/" 
    end

    private

    def load_user_from_params
        unless params[:email_address].empty?
            @user = User.find_by_email_address(params[:email_address])
        end
    end

    def restrict_logged_in
        if current_user
            redirect_to users_path, flash: {error: 'You are alread logged in!'} and return
        end
    end        
end