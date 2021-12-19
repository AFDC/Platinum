class CovidController < ApplicationController
  def index
    @vaxed_players = User.where(confirmed_covid_vax: true).order_by(lastname: :asc, firstname: :asc)
  end

  def confirm_vax_status
    confirm_players_ids = params["vax_confirmed_player_ids"]

    confirm_players_ids.each do |pid|
      next if pid.empty?

      p = User.find(pid)
      next if p.confirmed_covid_vax?

      p.confirmed_covid_vax = true
      p.save(validate: false)
      log_audit('ConfirmVax', user: p)
    end

    redirect_to '/covid' and return
  end
end
