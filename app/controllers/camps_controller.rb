class CampsController < ApplicationController
  before_action :authenticate_user!, except: [:show, :index]
  before_action :load_camp!, except: [:index, :new, :create, :export_csv]
  before_action :enforce_delete_permission!, only: [:destroy, :archive]
  before_action :enforce_guide!, only: %i(tag)
  before_action :enforce_grant_lockdown!, only: %i(update_grants)
  before_action :load_lang_detector, only: %i(show index)

  def index
    filter = params[:filterrific]&.symbolize_keys || { sorted_by: 'updated_at_desc' }
    filter[:active] = true
    filter[:not_hidden] = true

    if (!current_user.nil? && (current_user.admin? || current_user.guide?))
      filter[:hidden] = true
      filter[:not_hidden] = false
    else
      filter[:sorted_by] = 'random'
    end

    @filterrific = initialize_filterrific(
      Camp,
      filter
    ) or return
    @camps = @filterrific.find.page(params[:page])

    if params[:id] == 'old'
      @camps = @camps.where.not(event_id: Rails.application.config.default_event)
      if params[:event]
        @camps = @camps.where(event_id: params[:event])
      end
      render 'chronicles'
    else
      render 'current'
    end
  end

  def new
    @camp = Camp.new
  end

  def edit
    @just_view = params[:just_view]
    @step_param = params[:step]
    @camp_fund_options = Camp::FUNDS_REQUEST_OPTIONS_NIS
  end

  def create
    # Create camp without people then add them
    unless Lockdown.instance.allowed?('submit_dream')
      flash[:alert] = t('dream_creation_not_enabled')
      return redirect_to root_path
    end
    @camp = Camp.new(camp_params)
    @camp.creator = current_user
    @camp.event_id = Rails.application.config.default_event
    if @camp.people.first.present? and create_camp
      @camp.update(:camp_manager_id => @camp.people.first.id)
      flash[:notice] = t('created_new_dream')
      return redirect_to edit_camp_path(id: @camp.id)
    end

    flash.now[:alert] = "#{t:errors_str}: #{@camp.errors.full_messages.uniq.join(', ')}"
    render :new
  end

  # Toggle granting

  def toggle_granting
    @camp.toggle!(:grantingtoggle)
    redirect_to camp_path(@camp)
  end

  # Handle the grant updates in their own controller action
  def update_grants
    # Reduce the number of grants assigned to the current user by the number
    # of grants given away. Increase the number of grants assigned to the
    # camp by the same number of grants.

    # Decrement user grants. Check first if granting more than needed.
    granted = params['grants'].to_i
    if(granted <= 0)
      flash[:alert] = "#{t:cant_send_less_then_one}"
      redirect_to camp_path(@camp) and return
    end

    if @camp.maxbudget.nil?
      flash[:alert] = "#{t:dream_need_to_have_max_budget}"
      redirect_to camp_path(@camp) and return
    end

    if @camp.grants_received + granted > @camp.maxbudget
        granted = @camp.maxbudget - @camp.grants_received
    end

    if current_user.grants < granted
      flash[:alert] = "#{t:security_more_grants, granted: granted, current_user_grants: current_user.grants}"
      redirect_to camp_path(@camp) and return
    end

    ActiveRecord::Base.transaction do
      current_user.grants -= granted

      # Increase camp grants.
      @camp.grants.new({:user_id => current_user.id, :amount => granted})      

      if @camp.grants_received + granted >= @camp.minbudget
        @camp.minfunded = true
      else
        @camp.minfunded = false
      end
      
      if @camp.grants_received + granted >= @camp.maxbudget
        @camp.fullyfunded = true
      else
        @camp.fullyfunded = false
      end
        
      unless current_user.save
        flash[:notice] = "#{t:errors_str}: #{current_user.errors.full_messages.uniq.join(', ')}"
        redirect_to camp_path(@camp) and return
      end
      
      unless @camp.save
        flash[:notice] = "#{t:errors_str}: #{@camp.errors.full_messages.uniq.join(', ')}"
        redirect_to camp_path(@camp) and return
      end
    end

    @add_my_name = params[:add_my_name_cb]
    if(@add_my_name == '1')
      if not @camp.users.where(id: current_user.id).exists?
        @camp.users << current_user
      end
    end

    redirect_to camp_path(@camp)
    flash[:notice] = "#{t:thanks_for_sending, grants: granted}"
  end

  def update
    unless Lockdown.instance.allowed?('submit_dream')
      flash[:alert] = t('dream_creation_not_enabled')
      return redirect_to root_path
    end
    if (@camp.creator != current_user) and !current_user.admin and !current_user.guide
      flash[:alert] = "#{t:security_cant_edit_dreams_you_dont_own}"
      redirect_to camp_path(@camp) and return
    end

    #check if it is one of the public fields
    is_all_public = true
    camp_params.keys.each do |key|
      if !is_attribute_public key
        is_all_public = false
      end
    end

    if !is_all_public and Rails.configuration.x.firestarter_settings["disable_editing_dream"]
      #trying to edit a non public field - dream-creator can't edit
      if current_user.admin or current_user.guide
        # allow access
      elsif (@camp.creator == current_user)
        flash[:alert] = "#{t:security_cant_edit_dream}"
        redirect_to camp_path(@camp) and return
      #now only admin or guide can edit
      elsif !current_user.admin and !current_user.guide
        flash[:alert] = "#{t:security_cant_edit_dreams_you_dont_own}"
        redirect_to camp_path(@camp) and return
      end
    end

    safety_comments_updated = false
    if camp_params.keys.include?('safety_file_comments') &&
        camp_params['safety_file_comments'] != @camp.safety_file_comments
      safety_comments_updated = true
    end

    if @camp.update_attributes camp_params
      if safety_comments_updated
        send_safety_comments_update_notifications(current_user)
      end

      if params[:done] == '1'
        update_team_members_on_spark()
        redirect_to camp_path(@camp)
      else
        if params[:step]
          new_step = params[:step].to_i
          if (new_step < 6)
            new_step = new_step + 1
          end
          respond_to do |format|
            format.html { redirect_to edit_camp_path(id: @camp.id, step: new_step) }
            format.json { respond_with_bip(@camp) }
          end
        else
          respond_to do |format|
            format.html { redirect_to edit_camp_path(id: @camp.id) }
            format.json { respond_with_bip(@camp) }
          end
        end
      end
    else
      respond_to do |format|
        flash[:alert] = "#{t:errors_str}: #{@camp.errors.full_messages.uniq.join(', ')}"
        format.html { redirect_to edit_camp_path(id: @camp.id, step: params[:step].to_i) }
        format.json { respond_with_bip(@camp) }
      end
    end
  end

  def update_team_members_on_spark()
    if !Rails.configuration.x.firestarter_settings['spark_people']
      return
    end
    Rails.logger.debug("Updating team members on spark...")
    dream_info = {
      id: @camp.id,
      name: @camp.name,
      event: @camp.event_id,
    }
    Rails.logger.debug(dream_info.to_s)
    team_members = @camp.people.map do |r| 
      {
        name: r.name,
        email: r.email
      }
    end
    Rails.logger.debug(team_members.to_s)
    
    r = HTTParty.post(ENV['SPARK_PEOPLE_URL'].to_s, body: { dream:  dream_info, members: team_members, token: ENV['SPARK_TOKEN'] })
    if r['status'] == "true"
      Rails.logger.debug("Updated team members successfully!")
    else
      Rails.logger.error("Cant update team members on spark!")
      Rails.logger.error(r['body'])
      Rails.logger.error(r['code'])
      Rails.logger.error(r['message'])
    end
  end

  def tag
    @camp.update_attributes(tag_list: params.require(:camp).require(:tag_list))

    flash[:notice] = "#{t:tags_saved}"
    redirect_to camp_path(@camp)
  end

  def destroy
    @camp.destroy!

    redirect_to camps_path
  end

  # Display a camp and its users
  def show
    @users = @camp.users.select(:email)
    if @camp.default_image.present?
      @mainImage = @camp.default_image.attachment.url(:large)
    end

    # Added this to move some code out of the view.
    if current_user
      @user_grant_limit = current_user.grants
    end
  end

  # Allow a user to join a particular camp.
  def join
    @user = current_user

    #
    # Only add a user to the list of associated members if the user isn't
    # in the list. We should add a uniqueness validation to this.
    #

    if !@user
      flash[:notice] = "#{t:join_dream}"
    elsif @camp.users.where(id: @user.id).exists?
      flash[:notice] = "#{t:join_already_sent}"
    else
      flash[:notice] = "#{t:join_dream}"
      @camp.users << @user
    end
    redirect_to @camp
  end

  def archive
    @camp.update!(active: false)
    redirect_to camps_path
  end

  def export_csv
    unless current_user.admin
      redirect_to root_path
      return
    end

    send_data Camp.all.to_csv, :filename => "dreams-#{Date.today}.csv"
  end

  private

  def is_attribute_public (attribute)
    Camp::PUBLIC_ATTRIBUTES.include? attribute
  end

  def camp_params
    params.require(:camp).permit!
  end

  def load_camp!
    @camp = Camp.find_by(id: params[:id])
    if @camp.nil?
      flash[:alert] = t('dream_not_found')
      redirect_to camps_path
    end
  end

  def enforce_guide!
    if (!current_user.admin) && (!current_user.guide)
      flash[:alert] = "#{t:security_cant_tag_dreams_you_dont_own}"
      redirect_to camp_path(@camp)
    end
  end

  def enforce_delete_permission!
    if (@camp.creator != current_user) and (!current_user.admin)
      flash[:alert] = "#{t:security_cant_delete_dreams_you_dont_own}"
      redirect_to camp_path(@camp)
    end
  end

  def enforce_grant_lockdown!
    unless Lockdown.instance.allowed?('vote_hearts') and Rails.configuration.x.firestarter_settings["granting_active"]
      flash[:alert] = "#{t:security_cant_grant_anymore}"
      redirect_to camp_path(@camp)
    end

    if (not @camp.grantingtoggle) or @camp.minbudget.blank? and @camp.maxbudget.blank?
      flash[:alert] = "#{t:no_granting_yet}"
      redirect_to camp_path(@camp)
    end
  end

  def create_camp
    Camp.transaction do
      @camp.save!
      begin
        if Rails.application.config.x.firestarter_settings['google_drive_integration'] and ENV['GOOGLE_APPS_SCRIPT'].present?
          response = NewDreamAppsScript::createNewDreamFolder(@camp.creator.email, @camp.id, @camp.name)
          @camp.google_drive_folder_path = response['id']
          @camp.google_drive_budget_file_path = response['budget']
          @camp.save!
        end
      rescue
        flash[:alert] = "#{t:failed_to_create_google_drive_integration}"
      end
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def load_lang_detector
    @detector = StringDirection::Detector.new(:dominant)
  end

  def send_safety_comments_update_notifications(updating_user)
    CampMailer.safety_comments_updated(@camp, updating_user).deliver_later
  end
end
