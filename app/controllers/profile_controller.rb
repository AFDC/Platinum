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
    
    # Update any existing registrations for leagues that haven't started yet
    # current_user.registrations.where({'league_id' => {'$in' => League.future.map(&:_id)}})

    redirect_to user_profile_path, notice: 'Your gRank has been updated successfully.'
  end
end