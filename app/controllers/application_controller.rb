class ApplicationController < ActionController::Base
  helper :all

  # Only allow modern browsers supporting webp images, web push, badges, import maps,
  # CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :set_locale
  before_action :configure_sentry
  before_action :store_user_location!, if: :storable_location?

  rescue_from CanCan::AccessDenied do |_exception|
    if current_user
      render_not_found
    else
      redirect_to new_user_session_url
    end
  end

  rescue_from ActiveRecord::RecordNotFound do
    render_not_found
  end

  def initialize_memory_cache
    NastyCache.instance.initialize_request
  end

  def set_locale
    if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym)
      session[:locale] = params[:locale]
      redirect_to(params.permit!.except(:locale)) if request.get?
    end

    # set locale based on session or url
    I18n.locale =
      session[:locale] || http_accept_language.preferred_language_from(I18n.available_locales)
  end

  private

  def require_user
    return if current_user

    flash[:notice] = I18n.t("flash.need_login")
    redirect_to new_user_session_path
    false
  end

  # Its important that the location is NOT stored if:
  # - The request method is not GET (non idempotent)
  # - The request is handled by a Devise controller such as Devise::SessionsController as that could cause an
  #    infinite redirect loop.
  # - The request is an Ajax request as this can lead to very unexpected behaviour.
  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
  end

  def store_user_location!
    # :user is the scope we are authenticating
    store_location_for(:user, request.fullpath)
  end

  def after_sign_in_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || super
  end

  def configure_sentry
    if respond_to?(:current_user) && current_user
      Sentry.set_user(id: current_user.id, email: current_user.email)
    end
  end

  def engine_client
    # MyEtm::Auth.client_app_client(current_user, :engine)
    Faraday.new("http://localhost:3000")
  end

  # Internal: Renders a 404 page.
  #
  # thing - An optional noun, describing what thing could not be found. Leave
  #         nil to say "the page cannot be found"
  #
  # For example
  #   render_not_found('scenario') => 'the scenario cannot be found'
  #
  # Returns true.
  def render_not_found(thing = nil)
    content = Rails.root.join("public/404.html").read

    unless thing.nil?
      # Swap out the word "page" for something else, when appropriate.
      document = Nokogiri::HTML.parse(content)
      header = document.at_css("h1")
      header.content = header.content.sub(/\bpage\b/, thing)

      content = document.to_s
    end

    render(
      html: content.html_safe,
      status: :not_found,
      layout: "errors"
    )

    true
  end

  def turbo_notice(message = nil)
    if message.nil?
      message = flash[:notice]
      flash.delete(:notice)
    end

    return if message.nil?

    turbo_stream.update(
      "toast",
      ToastComponent.new(type: :notice, message:).render_in(view_context)
    )
  end

  def turbo_alert(message = nil)
    if message.nil?
      message = flash[:alert]
      flash.delete(:alert)
    end

    return if message.nil?

    turbo_stream.update(
      "toast",
      ToastComponent.new(type: :alert, message:).render_in(view_context)
    )
  end
end
