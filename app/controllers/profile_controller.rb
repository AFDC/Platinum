class ProfileController < ApplicationController
  def index
    @user = current_user

    render "users/show"
  end

  def update_g_rank
    answers = params.permit(:experience, :level_of_play, :athleticism, :ultimate_skills)

    begin
        score = GRank.calculate_score(answers)
    rescue => e
        redirect_to edit_g_rank_profile_path, flash: {error: e.message} and return
    end

    grr = GRankResult.new({answers: answers, score: score, user: current_user})

    unless grr.save
       redirect_to edit_g_rank_profile_path, flash: {error: "Could not save result."} and return
    end

    # Update any existing registrations
    current_user.registrations.where({'league_id' => {'$in' => League.current.map(&:_id)}}).each do |r|
      next unless r.league.require_grank?
      next unless r.league.start_date.beginning_of_day > Time.now

      r.g_rank_result = grr
      r.g_rank = grr.score
      r.save
    end

    if league_id = session[:post_grank_redirect]
      session.delete(:post_grank_redirect)
      redirect_to register_league_path(league_id)
    else
      redirect_to user_profile_path, notice: 'Your gRank has been updated successfully.'
    end
  end
end
