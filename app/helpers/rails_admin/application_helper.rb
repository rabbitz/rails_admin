require 'rails_admin/i18n_support'

module RailsAdmin
  module ApplicationHelper

    include RailsAdmin::I18nSupport

    def authorized?(*args)
      @authorization_adapter.nil? || @authorization_adapter.authorized?(*args)
    end
    
    def current_action?(action)
      @action.custom_key == action.custom_key
    end
    
    def edit_user_link
      return nil unless authorized?(:edit, _current_user.class, _current_user) && _current_user.respond_to?(:email)
      return nil unless abstract_model = RailsAdmin.config(_current_user.class).abstract_model
      return nil unless edit_action = RailsAdmin::Config::Actions.find(:edit, {:controller => self.controller, :abstract_model => abstract_model, :object => _current_user })
      link_to _current_user.email, url_for(:action => edit_action.action_name, :model_name => abstract_model.to_param, :id => _current_user.id)
    end

    
    def wording_for(label, options = {})
      action = case 
      when options[:action].nil?
        @action
      when options[:action].is_a?(Symbol) || options[:action].is_a?(String)
        RailsAdmin::Config::Actions.find(options[:action].to_sym, { :controller => self.controller })
      else
        options[:action]
      end
      
      model_config = options[:model_config] || options[:abstract_model] && RailsAdmin.config(options[:abstract_model]) || @model_config
      object = options[:object] || (model_config == @model_config) && @object || nil # don't use @object if model_config is not the current @model_config!
      
      I18n.t("admin.actions.#{action.i18n_key}.#{label}", 
        :model_label => model_config.try(:label), 
        :model_label_plural => model_config.try(:label_plural), 
        :object_label => model_config && object.try(model_config.object_label_method)
      )
    end
    
    def breadcrumb action = @action, acc = []
      acc << content_tag(:li, :class => "#{"active" if current_action?(action)}") do
        if action.http_methods.include?(:get) && authorized?(action.authorization_key, @abstract_model, @object)
          link_to wording_for(:breadcrumb, :action => action), { :action => action.action_name, :controller => 'rails_admin/main' }
        else
          content_tag(:span, wording_for(:breadcrumb, :action => action))
        end
      end

      unless action.breadcrumb_parent # rec tail
        content_tag(:ul, :class => "breadcrumb") do
          acc.reverse.join('<span class="divider">/</span>').html_safe
        end
      else
        breadcrumb RailsAdmin::Config::Actions.find(action.breadcrumb_parent, { :controller => self.controller, :abstract_model => @abstract_model, :object => @object }), acc # rec
      end
    end
    
    # parent => :root, :model, :object
    def menu_for(parent, options = {}) # perf matters here (no action view trickery)
      abstract_model = options[:model_config].try(:abstract_model) || options[:abstract_model] || @abstract_model
      object = options[:object] || (abstract_model == @abstract_model) && @object || nil # don't use @object if abstract_model is not the current @abstract_model!

      actions = RailsAdmin::Config::Actions.send(parent, { :controller => self.controller, :abstract_model => abstract_model, :object => object }).select{ |action| action.http_methods.include?(:get) && authorized?(action.authorization_key, abstract_model, object) }

      actions.map do |action|
        %{
          <li class="#{action.key}_#{parent}_link #{'active' if current_action?(action)}">
            <a href="#{url_for({ :action => action.action_name, :controller => 'rails_admin/main', :model_name => abstract_model.try(:to_param), :id => object.try(:id) })}">
              #{wording_for(:menu, options.merge(:action => action))}
            </a>
          </li>
        }
      end.join.html_safe
    end
    
    def bulk_menu abstract_model = @abstract_model
      actions = RailsAdmin::Config::Actions.all({ :controller => self.controller, :abstract_model => abstract_model }).select(&:bulkable?).select{ |action| authorized?(action.authorization_key, abstract_model) }
      return '' if actions.empty?
      content_tag :li, { :class => 'dropdown', :style => 'float:right', :'data-dropdown' => "dropdown" } do
        content_tag(:a, { :class => 'dropdown-toggle', :href => '#' }) { t('admin.misc.bulk_menu_title') } +
        content_tag(:ul, :class => 'dropdown-menu') do
          actions.map do |action|
            content_tag :li do
              link_to_function wording_for(:bulk_link, :action => action), "jQuery('#bulk_action').val('#{action.action_name}'); jQuery('#bulk_form').submit()"
            end
          end.join.html_safe
        end
      end
    end
  end
end

