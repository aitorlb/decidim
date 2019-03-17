# frozen_string_literal: true

require "cell/partial"

module Decidim
  module Proposals
    # This cell renders Wizard Step Form for Porposals/CollaborativeDrafts
    class WizardStepFormCell < Decidim::ViewModel
      include ProposalCellsHelper
      include CollaborativeDraftCellsHelper
      include Cell::ViewModel::Partial

      def show
        render
      end

      private

      def action
        params[:action].to_sym
      end

      def current_step
        @current_step = case action
                        when :new, :create
                          1
                        when :compare
                          2
                        when :complete, :destroy, :destroy_draft, :update, :update_draft
                          3
                        when :preview
                          4
                        end
      end

      def current_step_title
        @current_step_title = case action
                              when :create
                                :new
                              when :update_draft, :update
                                :complete
                              else
                                action
                              end
      end

      def step?(step)
        current_step == step
      end

      def model_name(singular = false)
        return model.model_name.singular_route_key if singular
        model.model_name.route_key
      end

      def url_to(action)
        url = case action
              when :index
                send("#{model_name}_path")
              when :compare
                send("compare_#{model_name(:singular)}_path")
              when :complete
                send("complete_#{model_name(:singular)}_path")
              when :discard
                send("#{model_name(:singular)}_path")
              end
        url
      end

      def presenter
        @presenter ||= if step?(1) || step?(3)
                         "Decidim::Proposals::#{model.model_name.name}Presenter".constantize.new(model)
                       elsif step?(4)
                         "#{model.model_name.name}Presenter".constantize.new(model)
                       end
      end

      def text(key)
        current_scope = "decidim.proposals.#{model_name}.#{current_step_title}"
        t(key, scope: current_scope)
      end

      def title(options = {})
        presenter.title(options)
      end

      def body(options = {})
        presenter.body(options)
      end

      # COMPARE methods
      def similar_resources
        @options[:similar_resources]
      end

      # COMPLETE methods
      def complete_form_options
        return unless model_name == "proposals"
        { url: update_draft_proposal_path(@options[:proposal]), method: :patch }
      end

      def user_groups?
        model.current_organization.user_groups_enabled? && Decidim::UserGroups::ManageableUserGroups.for(current_user).verified.any?
      end

      def scopes?
        return false unless model.current_participatory_space.has_subscopes?
        _prefixes << "#{Rails.root}/../decidim-core/app/views" # rubocop:disable Rails/FilePath
      end

      # PREVIEW
      def document
        model.documents.first
      end

      def photo
        model.photos.first
      end

      # WIZARD ASIDE methods
      #
      # Returns the list with all the steps, in html
      def wizard_stepper
        content_tag :ol, class: "wizard__steps" do
          out = wizard_stepper_step(1)
          out << wizard_stepper_step(2)
          out << wizard_stepper_step(3)
          out << wizard_stepper_step(4)
          out
        end
      end

      # Returns the list item of the given step, in html
      def wizard_stepper_step(step)
        content_tag(:li, wizard_step_name(step), class: wizard_step_classes(step))
      end

      # Returns the name of the step, translated
      def wizard_step_name(step)
        t("decidim.proposals.#{model_name}.wizard_steps.step_#{step}")
      end

      # Returns the css classes used for the proposal wizard for the desired step
      def wizard_step_classes(step)
        classes = if step?(step)
                    %(step--active step_#{step})
                  elsif step < current_step
                    %(step--past step_#{step})
                  else
                    %()
                  end
        classes
      end

      # Returns the url to the back link
      def wizard_aside_back_url
        url = case current_step
              when 1
                url_to(:index)
              when 3
                url_to(:compare)
              when 4
                url_to(:complete)
              end
        url
      end

      def wizard_aside_text(key)
        scope = "decidim.proposals.#{model_name}.wizard_aside"

        t(key, scope: scope)
      end

      # WIZARD HEADER methods
      def announcement
        locals = {}
        if translated_attribute(component_settings.new_proposal_help_text).present? && !step?(:step_4)
          locals[:announcement] = component_settings.new_proposal_help_text
        elsif step?(:step_4)
          locals[:callout_class] = "warning"
          locals[:announcement] = t("decidim.proposals.proposals.preview.proposal_edit_before_minutes",
                                    count: component_settings.proposal_edit_before_minutes)
        end
        locals
      end

      def help_text
        locals = {}
        help_text = component_settings.try("proposal_wizard_#{current_step}_help_text")
        if translated_attribute(help_text).present?
          locals[:announcement] = help_text
          locals[:callout_class] = step?(:step_2) ? "warning" : nil
        end
        locals
      end

      # Returns a string with the current step number and the total steps number
      def proposal_wizard_current_step
        content_tag(:span, class: "text-small") do
          out = t(:"decidim.proposals.proposals.wizard_steps.step_of",
                  current_step_num: current_step,
                  total_steps: 4)
          out << " (#{content_tag(:a,
                                  t(:"decidim.proposals.proposals.wizard_steps.see_steps"),
                                  "data-toggle": "steps")})"
          out
        end
      end

      # Returns the page title of the given step, translated
      def proposal_wizard_step_title
        t("decidim.proposals.#{model_name}.#{current_step_title}.title")
      end
    end
  end
end
