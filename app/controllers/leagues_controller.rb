class LeaguesController < ApplicationController
    before_filter :load_league_from_params, only: [:register, :registrations, :capture_payments, :show, :manage_roster, :upload_roster, :setup_roster_import, :import_roster, :edit, :update, :select_pair]
    before_filter :initialize_roster_csv, only: [:manage_roster, :upload_roster, :setup_roster_import, :import_roster]
    filter_access_to [:capture_payments], attribute_check: true

    def index
    end

    def new
        @league = League.new
    end

    def create
        @league = League.new(league_params)

        if @league.save
            redirect_to @league, notice: "League Created Successfully"
        else
            render :new
        end
    end

    def update
        if @league.update_attributes(league_params)
            redirect_to @league, notice: "League Updated Successfully"
        else
            render :edit
        end
    end

    def register
        if (Registration.where(league_id: @league._id, user_id: current_user._id).count > 0)
            redirect_to registrations_user_path(current_user), notice: "You've already registered for that league."
            return
        end

        if @league.require_grank? && current_user.g_rank_results.last.timestamp.end_of_day < 6.months.ago
            redirect_to edit_g_rank_profile_path, notice: "Your gRank score is out of date, please complete the survey before registering."
            return
        end

        @registration = Registration.new()
        @registration.league = @league
        @registration.user = current_user;
        render "registrations/edit"
    end

    def registrations
        @registrant_ids = []
        @registrant_data = {}
        @league.registrations.each do |reg|
            @registrant_ids << reg._id.to_s
            @registrant_data[reg._id.to_s] = {
                _id: reg._id.to_s,
                status: reg.status,
                name: reg.user.name,
                profile_img_url: reg.user.avatar.url(:roster),
                thumbnail_img_url: reg.user.avatar.url(:thumbnail),
                profile_url: user_path(reg.user),
                registration_url: registration_path(reg),
                gender: reg.gender,
                gen_availability: reg.gen_availability,
                rank: reg.rank,
                eos: reg.eos_availability,
                player_type: reg.player_strength,
                height: reg.user.height_in_feet_and_inches
            }
        end
    end

    def manage_roster
        @orphans = []
        @intruders = {}

        # Populate the intruders list, we'll cull this later
        @league.teams.each do |t|
            t.players.each do |p|
                @intruders[p._id] = t._id
            end
        end

        # Check each registration to see if that user is on a team
        @league.registrations.where(status: 'active').each do |r|
            u = r.user
            if @intruders.has_key? u._id
                # User has a registration, therefore is not an intruder
                @intruders.delete(u._id)
            else
                # User is not on a team yet, add to orphans
                @orphans << u._id
            end
        end

        if session[:roster_csv][@league._id] && File.file?(session[:roster_csv][@league._id])
            @has_roster_upload = true;
        else
            @has_roster_upload = false;
            session[:roster_csv].delete(@league._id) if session[:roster_csv][@league._id]
        end
    end

    def upload_roster
        begin
            SmarterCSV.process(params[:roster].path, {remove_empty_values: false, chunk_size: 2}) do |chunk|
                new_csv_path = ENV['roster_csv_path'] + "/roster_upload_" + Digest::SHA1.hexdigest([Time.now, rand].join)[0..16] + ".csv"

                FileUtils.cp params[:roster].path, new_csv_path
                session[:roster_csv][@league._id] = new_csv_path
                redirect_to setup_roster_import_league_path(@league) and return
            end
        rescue => e
            redirect_to manage_roster_league_path(@league), flash: {error: "There was an error reading that CSV file. (#{e})"} and return
        end
    end

    def setup_roster_import
        target_file = session[:roster_csv][@league._id]
        unless File.file?(target_file.to_s)
           redirect_to manage_roster_league_path(@league), flash: {error: "No uploaded roster file found"} and return
        end

        SmarterCSV.process(target_file, {remove_empty_values: false, chunk_size: 10}) do |chunk|
            @sample_data = chunk
        end

        @columns = @sample_data[0].keys

        @columns.each do |field_name|
            item = @sample_data[0][field_name]
            if item.match /^[0-9a-fA-F]{24}$/
                if User.find(item)
                    @user_id_field_guess = field_name
                elsif Team.find(item)
                    @team_id_field_guess = field_name
                end
            end
        end
    end

    def import_roster
        team_id_list = @league.teams.map{ |t| t._id}
        target_file = session[:roster_csv][@league._id]
        unless File.file?(target_file.to_s)
           redirect_to manage_roster_league_path(@league), flash: {error: "No uploaded roster file found"} and return
        end

        @successful_imports = 0
        @errors = []
        team_id_field = params[:team_id_field].to_sym
        user_id_field = params[:user_id_field].to_sym

        SmarterCSV.process(target_file, {remove_empty_values: false, chunk_size: 100}) do |chunk|
            chunk.each do |row|
                team_id = row[team_id_field]
                unless team_id
                    error_row = row
                    error_row[:error] = "Team ID was blank"
                    @errors << error_row
                    next
                end

                user_id = row[user_id_field]
                unless user_id
                    error_row = row
                    error_row[:error] = "User ID was blank"
                    @errors << error_row
                    next
                end

                team = Team.find(team_id)
                unless team
                    error_row = row
                    error_row[:error] = "Team not found for ID #{team_id}"
                    @errors << error_row
                    next
                end

                user = User.find(user_id)
                unless user
                    error_row = row
                    error_row[:error] = "User not found for ID #{user_id}"
                    @errors << error_row
                    next
                end

                #remove the user from their previous teams:
                Team.where("league_id" => @league._id).pull_all(:players, [user._id])
                User.where("_id" => user._id).pull_all(:teams, team_id_list)

                # Add the new team
                User.where("_id" => user._id).add_to_set(:teams, team._id)
                Team.where("_id" => team._id).add_to_set(:players, user._id)
                @successful_imports += 1
            end
        end

        # Clear out
        File.delete(target_file)
        session[:roster_csv].delete(@league._id)

        if @errors.count == 0
            redirect_to manage_roster_league_path(@league), notice: "#{@successful_imports} records were imported with no errors." and return
        end
    end

    def capture_payments
        @men = []
        @women = []
        @errors = []
        good_ids = []

        params[:reg_id].each do |reg_id|
            r = Registration.find(reg_id)

            if r
                if r.status == 'authorized'
                    @men << r if r.gender == 'male'
                    @women << r if r.gender == 'female'
                    good_ids << r._id.to_s
                else
                    @errors << "Payment not yet authorized for #{r.user.name}."
                end
            else
                @errors << "Registration not found for #{reg_id}"
            end
        end

        flash[:error] = "Errors were found in your submission, see below" if @errors.count > 0

        if params[:confirm] == '1' && @errors.count == 0
            good_ids.each do |reg_id|
                PaymentCaptureWorker.perform_async(reg_id)
            end
            redirect_to registrations_league_path(@league), notice: "#{@men.count + @women.count} registrations queued for capture, this may take some time."
        end
    end

    private

    def load_league_from_params
        begin
            @league = League.find(params[:id])
        rescue
            redirect_to leagues_path, flash: {error: "Could not load League for ID '#{params[:id]}', please try a different field."}
        end
    end

    def initialize_roster_csv
        session[:roster_csv] = {} unless session[:roster_csv]
    end

    def league_params
        permitted_params = [
            :name, :age_division, :season, :sport, :price,
            :start_date, :end_date, :registration_open, :registration_close,
            :description, {commissioner_ids: []},
            :require_grank, :allow_pairs, :allow_self_rank, :core_type,
            :eos_tourney, :mst_tourney
        ]

        if permitted_to? :assign_comps, self
            permitted_params << {comped_player_ids: []}
            permitted_params << {comped_group_ids: []}
        end

        params.require(:league).permit(*permitted_params)
    end
end
