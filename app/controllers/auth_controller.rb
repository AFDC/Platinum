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

        session[:user_id] = @user._id.to_s

        if params[:remember_me]
            @user.remember_me_cookie = SecureRandom.hex(32)
            cookies[:platinum_login] = @user.remember_me_cookie
        else
            @user.remember_me_cookie = nil
        end

        @user.save

        if session[:login_redirect_url]
            redirect_to session[:login_redirect_url]
            session.delete(:login_redirect_url)
        else
            redirect_to home_path
        end
    end

    def reset_password
        unless @user
            redirect_to forgot_password_path, flash: {error: 'User not found for that email address.'} and return
        end

        new_pw = @user.reset_password
        @user.save(validate: false)

        UserMailer.delay.password_reset(@user._id, new_pw)

        redirect_to auth_path, notice: "Please check your email for a password reset."
    end

    def logout
        @user = current_user

        unless session['real_user_id']
            @user.remember_me_cookie = nil
            @user.save

            cookies.delete(:platinum_login)

            reset_session
            redirect_to home_path and return
        end

        session['user_id'] = session['real_user_id']
        session.delete('real_user_id')
        redirect_to home_path, notice: "You are no longer logged in as #{@user.name}."
    end

    private

    def load_user_from_params
        unless params[:email_address].empty?
            @user = User.find_by_email_address(params[:email_address])
        end
    end

    def restrict_logged_in
        if current_user
            redirect_to home_path, flash: {error: 'You are alread logged in!'} and return
        end
    end
end
