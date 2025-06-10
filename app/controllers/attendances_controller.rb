class AttendancesController < ApplicationController
  before_filter :load_attendance_by_params, only: [:show, :create, :update]
  before_filter :load_attendance_by_id, only: [:destroy]
  before_filter :load_attendance_from_signed_token, only: [:quick_update]
  before_filter :load_attendance_from_twilio_token, only: [:twilio_webhook]
  
  # Skip CSRF for Twilio webhooks
  skip_before_filter :verify_authenticity_token, only: [:twilio_webhook, :twilio_webhook_failure]

  def show
  end

  def create
    if @attendance.update_attributes(attendance_params)
      redirect_to team_path(@team), notice: "Attendance updated successfully."
    else
      render :show
    end
  end

  def update
    if @attendance.update_attributes(attendance_params)
      redirect_to team_path(@team), notice: "Attendance updated successfully."
    else
      render :show
    end
  end

  def destroy
    @attendance.destroy
    redirect_to team_path(@attendance.team), notice: "Attendance record removed."
  end

  def quick_update
    attending = params[:attending] == 'true'
    
    @attendance.attending = attending
    @attendance.notes = nil  # Clear any existing notes for quick updates
    @attendance.updated_by = @user if @attendance.user != @user
    
    if @attendance.save
      status_text = attending ? "attending" : "not attending"
      redirect_to team_path(@team), notice: "Thanks! We've marked you as #{status_text} for #{@team.name} on #{@attendance.game_date.strftime('%A, %B %e')}."
    else
      redirect_to team_path(@team), alert: "Sorry, there was an error updating your attendance. Please try again."
    end
  end

  def twilio_webhook
    attending = params[:attending] == 'true'
    
    @attendance.attending = attending
    @attendance.updated_by = @user if @attendance.user != @user
    
    if @attendance.save
      status_text = attending ? "attending" : "not attending"
      Rails.logger.info "Twilio webhook: Updated attendance for #{@user.name} (#{@team.name} on #{@attendance.game_date}) - #{status_text}"
      
      render plain: "Thanks! We've recorded your response."
    else
      Rails.logger.error "Twilio webhook: Failed to update attendance for #{@user.name}: #{@attendance.errors.full_messages}"
      render status: :internal_server_error, plain: "Sorry, there was an error. Please try again later."
    end
  end

  def twilio_webhook_failure
    Rails.logger.error "Twilio webhook failure: #{params.inspect}"
    
    # Return TwiML response for failure
    render xml: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>We couldn't process your response. Please contact your team captain.</Say></Response>"
  end

  private

  def load_attendance_by_id
    @attendance = Attendance.find(params[:id])
    @team = @attendance.team
  end

  def load_attendance_by_params
    @team = Team.find(params[:team_id])
    @user = current_user
    
    # Check if user is on this team
    unless @team.players.include?(@user)
      redirect_to team_path(@team), flash: {error: "You can only update attendance for teams you're on."}
      return
    end
    
    game_date = Date.parse(params[:game_date]) if params[:game_date]
    
    @attendance = Attendance.find_or_initialize_by(
      team: @team,
      user: @user,
      game_date: game_date
    )
  end

  def load_attendance_from_signed_token
    begin
      # Verify and decode the signed token
      token_data = Rails.application.message_verifier('attendance').verify(params[:token])
      
      # Check expiration manually (7 days)
      if token_data['created_at'] && Time.parse(token_data['created_at']) < 7.days.ago
        redirect_to root_path, alert: "This attendance link has expired."
        return
      end
      
      @user = User.find(token_data['user_id'])
      @team = Team.find(token_data['team_id'])
      game_date = Date.parse(token_data['game_date'])
      
      # Verify user is still on the team
      unless @team.players.include?(@user)
        redirect_to team_path(@team), alert: "You are no longer on this team."
        return
      end
      
      @attendance = Attendance.find_or_initialize_by(
        team: @team,
        user: @user,
        game_date: game_date
      )
      
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
      redirect_to root_path, alert: "This attendance link is invalid or has expired."
    rescue Mongoid::Errors::DocumentNotFound
      redirect_to root_path, alert: "The user or team for this attendance link no longer exists."
    end
  end

  def load_attendance_from_twilio_token
    begin
      # Verify and decode the signed token
      token_data = Rails.application.message_verifier('twilio_attendance').verify(params[:token])
      
      # Check expiration manually (7 days)
      if token_data['created_at'] && Time.parse(token_data['created_at']) < 7.days.ago
        Rails.logger.error "Twilio webhook: Expired token"
        render xml: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>This request has expired.</Say></Response>"
        return
      end
      
      @user = User.find(token_data['user_id'])
      @team = Team.find(token_data['team_id'])
      game_date = Date.parse(token_data['game_date'])
      
      # Verify user is still on the team
      unless @team.players.include?(@user)
        Rails.logger.error "Twilio webhook: User no longer on team"
        render xml: "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You are no longer on this team.</Say></Response>"
        return
      end
      
      @attendance = Attendance.find_or_initialize_by(
        team: @team,
        user: @user,
        game_date: game_date
      )
      
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
      Rails.logger.error "Twilio webhook: Invalid token signature"
      render status: :unauthorized, plain: "Invalid request."
    rescue Mongoid::Errors::DocumentNotFound
      Rails.logger.error "Twilio webhook: User or team not found"
      render status: :not_found, plain: "User or team no longer exists."
    end
  end

  def attendance_params
    params.require(:attendance).permit(:attending, :notes, :game_date)
  end
end