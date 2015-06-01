class NotificationMethodsController < ApplicationController
    filter_resource_access nested_in: :users

    def create
        if @notification_method.save
            NotificationConfirmationWorker.perform_async(@notification_method._id.to_s)
            redirect_to user_notification_methods_path(@user), notice: "Notification Method Added Successfully"
        else
            render :new
        end
    end

    def update
        @notification_method.assign_attributes(update_params[:notification_method])
        if @notification_method.confirmed?
            @notification_method.enabled = (params[:notification_method][:enabled] == '1')
        end

        if @notification_method.save
            redirect_to user_notification_methods_path(@user), notice: "Notification Method Updated Successfully"
        else
            render :edit
        end
    end

    def confirm
        if params[:confirmation_code] == @notification_method.confirmation_code
            @notification_method.confirmation_code = nil
            @notification_method.confirmed         = true
            @notification_method.enabled           = true
            @notification_method.save

            redirect_to user_notification_methods_path(@user), notice: "You've confirmed your notification method and it has been enabled." and return
        end

        redirect_to enter_confirmation_user_notification_method_path(@user, @notification_method), flash: {error: "Incorrect confirmation code." }
    end

    private

    def new_notification_method_from_params
        @notification_method = @user.notification_methods.new(new_params[:notification_method])
    end

    def new_params
        params.permit(notification_method: [:method, :target, :label])
    end

    def update_params
        params.permit(notification_method: [:label])
    end
end
