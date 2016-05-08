class LeaguesController < ApplicationController
    before_filter :load_league_from_params, except: [:index, :new, :create]
    before_filter :initialize_roster_csv, only: [:manage_roster, :upload_roster, :setup_roster_import, :import_roster]
    filter_access_to [:accept_players, :preview_capture], attribute_check: true

    def index
    end

    def show
        @registration = @league.registration_for(current_user)
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

        user_gender_limit = @league["#{current_user.gender}_limit".to_sym]

        if user_gender_limit == 0
            redirect_to league_path(@league), flash: {error: "No #{current_user.gender} registrants allowed."} and return
        end

        unless current_user.valid?
            redirect_to edit_user_path(current_user), notice: "Your user profile is incomplete, you must update it before registering."
            return
        end

        if @league.require_grank? && (current_user.g_rank_results.first.nil? || current_user.g_rank_results.first.timestamp.end_of_day < @league.max_grank_age.months.ago)
            session[:post_grank_redirect] = @league._id.to_s
            redirect_to edit_g_rank_profile_path, notice: "Your gRank score is out of date, please complete the survey before registering."
            return
        end

        @registration = Registration.new()
        @registration.league = @league
        @registration.user = current_user;
        render "registrations/edit"
    end

    def registrations
        respond_to do |format|
            format.html do
                @user_data = {
                    _id: current_user._id,
                }

                if user_reg = @league.registration_for(current_user)
                    @user_data[:registration_id] = user_reg._id.to_s
                    @user_data[:pair_id] = user_reg[:pair_id]
                    @pair_reg = @league.registration_for(user_reg.pair)
                    @reg_group = RegistrationGroup.where(league: @league, member_ids: current_user._id).first
                else
                    @user_data[:registration_id] = nil
                    @user_data[:pair_id] = nil
                end

                @user_data[:pair_invite_count] = Invitation.outstanding.where(type: 'pair', sender: current_user, handler_id: @league._id).count

                if Invitation.outstanding.where(type: 'pair', recipient: current_user, handler_id: @league._id).count > 0
                    flash.now[:notice] = "You have invitations waiting for you in this league. #{ActionController::Base.helpers.link_to("Click here", invitations_path)} to see them.".html_safe
                end
            end

            format.json do
                @registrant_data = Rails.cache.fetch("#{@league.cache_key}/registrant_summary", expires_in: 24.hours, race_condition_ttl: 10) do
                    rd = {}
                    @league.registrations.each do |reg|
                        next unless reg.user
                        uid = reg.user._id.to_s
                        rg = RegistrationGroup.where(league: @league, member_ids: reg.user._id).first
                        rd[uid] = {
                            registration_id: reg._id.to_s,
                            _id: reg.user._id.to_s,
                            status: reg.status,
                            name: reg.user.name,
                            profile_img_url: reg.user.avatar.url(:roster),
                            thumbnail_img_url: reg.user.avatar.url(:thumbnail),
                            profile_url: user_path(reg.user),
                            registration_url: registration_path(reg),
                            registration_group: rg.try(:_id),
                            pair_id: reg.pair_id,
                            gender: reg.gender,
                            gen_availability: reg.gen_availability,
                            rank: reg.rank,
                            eos: reg.eos_availability,
                            player_type: reg.player_strength,
                            height: reg.user.height_in_feet_and_inches,
                            grank: {},
                            age: reg.user.age,
                            linked: reg.linked?,
                            signup_timestamp: reg.signup_timestamp
                        }
                        rd[uid][:timestamps] = {}
                        rd[uid][:timestamps][:signup] = reg.signup_timestamp.to_i
                        reg.payment_timestamps.each do |key,ts|
                            rd[uid][:timestamps][key] = ts.to_i
                        end
                        if reg.g_rank_result
                            rd[uid][:grank][:score] = reg.g_rank_result.score
                            rd[uid][:grank][:answers] = GRank.convert_answers_to_text(reg.g_rank_result.answers)
                            rd[uid][:grank][:history] = reg.user.g_rank_results.map(&:score).slice(0,12).reverse
                        end
                    end
                    rd
                end
                render json: {reg_data: @registrant_data, reg_list: @registrant_data.keys}
            end

            format.csv do
                if params[:registration_ids]
                    @registrations = User.find(params[:registration_ids])
                else
                    @registrations = @league.registrations
                end
            end
        end
    end

    def leave_pair
        user_reg = @league.registration_for(current_user)
        if user_reg.pair
            pair_reg = @league.registration_for(user_reg.pair)

            user_reg.pair = nil
            user_reg.save!
            pair_reg.pair = nil
            pair_reg.save!

            # TODO: Send "goodbye" email
        end

        redirect_to registrations_league_path(@league), flash: {success: "You are no longer paired."}
    end

    def invite_pair
        errors = []
        user_reg = @league.registration_for(current_user)
        friend = User.find(params[:target_user_id])
        friend_reg = @league.registration_for(friend)

        begin
            unless current_user.present? && user_reg.present?
                errors << "You're not registered for this league."
            end

            unless friend.present? && friend_reg.present?
                errors << "Registration not found for that user."
            end

            raise StandardError unless user_reg.present? && friend_reg.present?

            unless friend_reg.status == 'active' && user_reg.status == 'active'
                errors << "Only active registrants may pair for a league."
            end

            if user_reg.pair.present?
                errors << "You've already got a pair!"
            end

            if friend_reg.pair.present?
                errors << "That user is already paired!"
            end

            if friend_reg == user_reg
                errors << "Don't freak out -- you'll definitely be on your own team."
            end

            if Invitation.outstanding.where(type: 'pair', sender: current_user, handler_id: @league._id).count > 0
                errors << "You have already made a pair request. You'll need to cancel that to make a new one"
            end
        rescue nil
        end

        if errors.empty?
            invite = Invitation.create!(
                type: 'pair',
                handler: @league,
                sender: current_user,
                recipient: friend
            )

            unless invite.persisted?
                errors << "Saving the invitation failed."
            end
        end

        respond_to do |format|
            format.json do
                if errors.empty?
                    render json: invite
                else
                    render json: errors, status: 500
                end
            end
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
            @has_roster_upload = true
        else
            @has_roster_upload = false
            session[:roster_csv].delete(@league._id) if session[:roster_csv][@league._id]
        end
    end

    def upload_roster
        begin
            SmarterCSV.process(params[:roster].path, {remove_empty_values: false, chunk_size: 2, row_sep: :auto}) do |chunk|
                new_csv_path = ENV['roster_csv_path'] + "/roster_upload_" + Digest::SHA1.hexdigest([Time.now, rand].join)[0..16] + ".csv"

                FileUtils.cp params[:roster].path, new_csv_path
                session[:roster_csv][@league._id] = new_csv_path
                redirect_to setup_roster_import_league_path(@league) and return
            end
            raise "No data found in the supplied file. Ensure the file contains data and that the lines are terminated by newline characters."
        rescue => e
            redirect_to manage_roster_league_path(@league), flash: {error: "There was an error reading that CSV file. (#{e})"} and return
        end
    end

    def setup_roster_import
        target_file = session[:roster_csv][@league._id]
        unless File.file?(target_file.to_s)
           redirect_to manage_roster_league_path(@league), flash: {error: "No uploaded roster file found"} and return
        end

        SmarterCSV.process(target_file, {remove_empty_values: false, chunk_size: 10, row_sep: :auto}) do |chunk|
            @sample_data = chunk
        end

        @columns = @sample_data[0].keys

        @columns.each do |field_name|
            item = @sample_data[0][field_name].to_s
            if item.match(/^[0-9a-fA-F]{24}$/)
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

    def upload_schedule
        csv       = SmarterCSV.process(params[:schedule].path)
        right_now = DateTime.now

        @results = []
        @skipped = 0

        csv.each do |row|
            begin
                missing_fields = [:game_time, :fieldsite_id, :field_num, :team1_id, :team2_id] - row.keys

                unless missing_fields.empty?
                    raise "Fields missing: #{missing_fields.join(', ')}"
                end

                begin
                    gt = Time.zone.parse(row[:game_time]).to_datetime
                rescue => e
                    raise "Couldn't figure out how to parse '#{row[:game_time]}', please format your dates as YYYY-MM-DD HH:MM:SS."
                end

                new_game = {
                    game_time: gt,
                    fieldsite: FieldSite.find(row[:fieldsite_id]),
                    field_num: row[:field_num],
                    teams:     [Team.find(row[:team1_id]), Team.find(row[:team2_id])]
                }

                raise "Game is in the past and will be skpped." unless new_game[:game_time] > right_now
                raise "FieldSite not found with ID '#{row[:fieldsite_id]}'" unless new_game[:fieldsite]
                raise "Team 1 not found with ID '#{row[:team1_id]}'" unless new_game[:teams][0]
                raise "Team 2 not found with ID '#{row[:team2_id]}'" unless new_game[:teams][1]

                @results << new_game
            rescue => e
                @results << { error: e.message }
            end
        end
    end

    def import_schedule
        failure = 0
        params[:games].each do |row, game_data|
            game = Game.new(
                league_id: @league._id, 
                game_time: Time.at(game_data[:game_time].to_i).to_datetime,
                fieldsite_id: FieldSite.find(game_data[:fieldsite_id])._id,
                field: game_data[:field_num],
            )

            game[:teams] = [Team.find(game_data[:team1_id])._id, Team.find(game_data[:team2_id])._id]
            failure +=0 unless game.save
        end

        redirect_to league_path(@league), notice: "Games successfully imported with #{failure} errors."
    end

    def remove_future_games
        game_list = @league.games.where(game_time: { "$gt" => DateTime.now });
        deleted = game_list.count
        game_list.delete_all

        redirect_to setup_schedule_import_league_path(@league), notice: "#{deleted} future games deleted."
    end

    def preview_capture
        if params[:registration_group_id] && @rg = RegistrationGroup.find(params[:registration_group_id])
            @authorized_registrants = {male: [], female: []}
            @rg.members.each do |m|
                if reg = @league.registration_for(m)
                    @authorized_registrants[reg.gender.to_sym] << reg if reg.status == 'pending'
                end
            end
        else
            @authorized_registrants = {}
            %w(male female).each do |gender|
                @authorized_registrants[gender.to_sym] = @league.registrations.pending.where(gender: gender).sort('signup_timestamp' => 1)
            end
        end
    end

    def accept_players
        @errors = []
        registrations = []

        submitted_ids = params[:reg_id] || []

        submitted_ids.each do |reg_id|
            r = Registration.find(reg_id)

            if r
                if r.status == 'cancelled'
                    @errors << "Registration cancelled for #{r.user.name}."
                end

                registrations << r
            else
                @errors << "Registration not found for #{reg_id}"
            end
        end

        if @errors.count > 0
            flash[:error] = "Errors were found in your submission, see below"
            render 'league/preview_capture' and return
        else
            expirations = @league.current_expiration_times
            registrations.each { |r| r.accept(expirations[r.gender.to_sym]) }
            redirect_to league_path(@league), notice: "#{registrations.count} registrants accepted. They will be invited to pay and join the league."
        end
    end

    def rainout_games
        @todays_games     = @league.games.where(:game_time.gte => Date.today.beginning_of_day, :game_time.lte => Date.today.end_of_day )
        @todays_fields    = {}
        @field_game_count = {}

        @todays_games.each do |g|
            fsid = g.field_site._id.to_s

            @todays_fields[fsid]    ||= g.field_site
            @field_game_count[fsid] ||= 0

            @field_game_count[fsid] += 1
        end
    end

    def process_rainout
        unless params[:fieldsite_ids].present? && params[:fieldsite_ids].count > 0
            redirect_to rainout_games_league_path(@league), flash: {error: "You must select one or more sites to rain out."}
            return
        end

        # Create job, queue jobs
        jobs = []

        params[:fieldsite_ids].each do |fsid|
            fs = FieldSite.find(fsid)
            unless fs.present?
                redirect_to rainout_games_league_path(@league), flash: {error: "Invalid field site (#{fsid})."}
                return
            end

            GameCancellationWorker.perform_async(@league._id.to_s, fsid, Date.today.beginning_of_day.to_i, Date.today.end_of_day.to_i, current_user._id.to_s, params[:notify])
        end

        redirect_to league_path(@league), notice: "We've started processing cancellations for those sites. It may take a few minutes for them all to be sent."
    end

    def missing_spirit_reports
        @games           = @league.games.where(:game_time.lte => Time.now)
        @missing_reports = {}

        @games.each do |game|
            next if game.rained_out?
            game.teams.each do |t|
                o = game.opponent_for(t)
                if game.spirit_report_for(t).nil?
                    @missing_reports[o._id.to_s] ||= []
                    @missing_reports[o._id.to_s] << game
                end
            end
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
            :description, {commissioner_ids: []}, :male_limit, :female_limit,
            :max_grank_age, :allow_pairs, :track_spirit_scores, :display_spirit_scores, :allow_self_rank, :eos_tourney, :mst_tourney, :eos_champion_id, :mst_champion_id,
            {core_options: [:type, :male_limit, :female_limit, :rank_limit, :male_rank_constant, :female_rank_constant]}
        ]

        if permitted_to? :assign_comps, self
            permitted_params << {comped_player_ids: []}
            permitted_params << {comped_group_ids: []}
        end

        params.require(:league).permit(*permitted_params)
    end
end
