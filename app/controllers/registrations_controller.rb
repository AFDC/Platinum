class RegistrationsController < ApplicationController
    def create
        reg_params = params[:registration]

        new_reg = Registration.new

        new_reg.league = League.find(reg_params[:league_id])
        new_reg.user = current_user

        unless new_reg.league
            redirect_to leagues_path, notice: 'League not found.'
            return
        end

        unless ['25%', '50%', '75%', '100%'].include?(reg_params[:availability])
            redirect_to register_league_path(new_reg.league), notice: "You must select and attendance percentage"
            return
        end

        unless ['1', '2', '3', '4', '5', '6', '7', '8', '9'].include?(reg_params[:self_rank])
            redirect_to register_league_path(new_reg.league), notice: "You must select a rank for yourself"
            return
        end

        unless ['Runner', 'Thrower', 'Both'].include?(reg_params[:player_strength])
            redirect_to register_league_path(new_reg.league), notice: "You must select a primary role"
            return
        end

        unless reg_params[:waiver_accepted] == '1'
            redirect_to register_league_path(new_reg.league), notice: "You must accept the waiver to register"
            return
        end

        # This is ugly, oh well.
        new_reg.availability = {general: reg_params[:availability]}
        new_reg.gender = current_user.gender
        new_reg.paid = false
        new_reg.player_strength = reg_params[:player_strength]
        new_reg.secondary_rank_data = {self_rank: reg_params[:self_rank]}
        new_reg.signup_timestamp = Time.now
        new_reg.status = 'pending'
        new_reg.user_data = {
            birthdate: current_user.birthdate,
            firstname: current_user.firstname,
            middlename: current_user.middlename,
            lastname: current_user.lastname,
            gender: current_user.gender,
            height: current_user.height,
            weight: current_user.weight
        }

        if new_reg.save
            redirect_to users_path, notice: "Woo! #{new_reg._id}"
        else
            redirect_to users_path, notice: new_reg.errors
        end
    end
end
