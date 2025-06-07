class AttendancesController < ApplicationController
  before_filter :load_attendance_by_params, only: [:show, :create, :update]
  before_filter :load_attendance_by_id, only: [:destroy]

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

  private

  def load_attendance_by_id
    @attendance = Attendance.find(params[:id])
    @team = @attendance.team
  end

  def load_attendance_by_params
    @team = Team.find(params[:team_id])
    @user = current_user
    game_date = Date.parse(params[:game_date]) if params[:game_date]
    
    @attendance = Attendance.find_or_initialize_by(
      team: @team,
      user: @user,
      game_date: game_date
    )
  end

  def attendance_params
    params.require(:attendance).permit(:attending, :notes, :game_date)
  end
end