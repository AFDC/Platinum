class SchedulesController < ApplicationController
    layout "new_homepage"
    def index
        # Get a default filter date
        @default_date = Date.today

        target_game = Game.where(:game_time.gte => Time.now.beginning_of_day).sort(game_time: 1).first
        target_game = Game.where(:game_time.lte => Time.now.end_of_day).sort(game_time: -1).first unless target_game

        @default_date = target_game.game_time.to_date if target_game && target_game.game_time

        # Get the league listing
        # @leagues = {}
        # League.only(:_id, :name).sort(start_date: -1).each do |l|
        #     @leagues[l.name] = l._id
        # end
        @leagues = League.only(:_id, :name).sort(start_date: -1)

        @fieldsites = FieldSite.only(:_id, :name).where(active: true).sort(name: 1)
    end

    def show
        @page_num = 1
        @page_size = 25
        query = {}

        @page_num = params['page_num'].to_i if params['page_num'].present?

        begin
            if params['on_date'].present?
                on_date = Date.parse(params['on_date'])
            end

            if params['start_date'].present?
                start_date = Date.parse(params['start_date'])
            end
        rescue
        end

        if on_date
            query[:game_time] = {
                "$gte" => on_date.beginning_of_day,
                "$lte" => on_date.end_of_day
            }
        elsif start_date
            query[:game_time] = {
                "$gte" => start_date.beginning_of_day,
            }
        end

        query[:league_id] = params['league_id'] if params['league_id'].present?
        query[:fieldsite_id] = params['fieldsite_id'] if params['fieldsite_id'].present?
        if params['sort_dir'] == 'DESC'
            sort_dir = -1
        else
            sort_dir = 1
        end

        @q = query

        @game_count = Game.where(query).count


        @games = Game.where(query).sort(game_time: sort_dir).skip(@page_size * (@page_num - 1)).limit(@page_size)

        respond_to do |format|
            format.html { render :layout => !request.xhr? }
        end
    end
end
