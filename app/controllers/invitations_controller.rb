class InvitationsController < ApplicationController
    before_filter :load_invite_from_params, only: [:cancel, :accept, :decline]

    def index
      layout "new_homepage"
      @sent = Invitation.where(sender: current_user).sort(updated_at: -1)
      @received = Invitation.where(recipient: current_user).sort(updated_at: -1)
    end

    def cancel
      @invitation.cancel

      if request.xhr?
        render text: 'success'
      else
        redirect_to invitations_path
      end
    end

    def decline
      @invitation.decline

      if request.xhr?
        render text: 'success'
      else
        redirect_to invitations_path
      end
    end

    def accept
      @invitation.accept

      if request.xhr?
        render text: 'success'
      else
        redirect_to invitations_path
      end
    end

    private

    def load_invite_from_params
      @invitation = Invitation.find(params[:id])

      unless @invitation.present?
        redirect_to invitations_path, flash: {error: "Could not load Group for ID '#{params[:id]}', please try again."} and return
      end
    end
end
