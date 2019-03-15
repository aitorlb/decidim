# frozen_string_literal: true

require "cell/partial"

module Decidim
  module Proposals
    # This cell renders the collaborative_draft card for an instance of a CollaborativeDraft
    # the default size is the Medium Card (:m)
    class WizardStepFormCell < Decidim::ViewModel
      include ProposalCellsHelper
      include CollaborativeDraftCellsHelper
      include Cell::ViewModel::Partial

      def show
        render
      end

      private

      def title
        presenter.title
      end

      def body
        presenter.body
      end

      def model_name(singular = false)
        return model.model_name.singular_route_key if singular
        model.model_name.route_key
      end

      def similar_resources
        @options[:similar_resources]
      end

      def wizard_aside_link_to_back
        action = params[:action].to_sym
        url = case action
              when :new, :compare
                send("#{model_name}_path")
              when :complete
                send("complete_#{model_name(:singular)}_path")
              when :preview
                send("preview_#{model_name(:singular)}_path")
              end
        icon("chevron-left", class: "icon--small")
        link_to url do
          out = icon("chevron-left", class: "icon--small")
          out << wizard_aside_back_text(action == :compare)
          out
        end
      end

      # Returns different text for step_2: compare
      def wizard_aside_back_text(_step_2 = false)
        scope = "decidim.proposals.#{model_name}.wizard_aside"
        # return t("exit", scope: scope).html_safe if step_2

        t("back", scope: scope)
      end

      def wizard_aside_info_text
        t("wizard_aside.info", scope: "decidim.proposals.#{model_name}")
      end

      def presenter
        @presenter ||= "Decidim::Proposals::#{model_name.name}Presenter".constantize.new(model)
      end

      def current_step
        @current_step = case action
                        when :new
                          :step_1
                        when :compare
                          :step_2
                        when :complete
                          :step_3
                        when :preview
                          :step_4
                        end
      end

      def action
        params[:action].to_sym
      end

      # Returns the list with all the steps, in html
      #
      # current_step - A symbol of the current step
      def proposal_wizard_stepper
        content_tag :ol, class: "wizard__steps" do
          %(
            #{proposal_wizard_stepper_step(:step_1)}
            #{proposal_wizard_stepper_step(:step_2)}
            #{proposal_wizard_stepper_step(:step_3)}
            #{proposal_wizard_stepper_step(:step_4)}
          ).html_safe
        end
      end

      # Returns the list item of the given step, in html
      #
      # step - A symbol of the target step
      # current_step - A symbol of the current step
      def proposal_wizard_stepper_step(step)
        content_tag(:li, proposal_wizard_step_name(step), class: proposal_wizard_step_classes(step).to_s)
      end

      # Returns the page title of the given step, translated
      #
      # action_name - A string of the rendered action
      def proposal_wizard_step_title
        step_title = case action
                     when "create"
                       "new"
                     when "update_draft"
                       "edit_draft"
                     else
                       action
                     end

        t("decidim.proposals.#{model_name}.#{step_title}.title")
      end

      # Returns the name of the step, translated
      #
      # step - A symbol of the target step
      def proposal_wizard_step_name(step)
        t("decidim.proposals.#{model_name}.wizard_steps.#{step}")
      end

      # Returns the css classes used for the proposal wizard for the desired step
      #
      # step - A symbol of the target step
      # current_step - A symbol of the current step
      #
      # Returns a string with the css classes for the desired step
      def proposal_wizard_step_classes(step)
        classes = if step?(step)
                    %(step--active #{step} #{current_step})
                  elsif step_to_i(step) < 4
                    %(step--past #{step})
                  else
                    %()
                  end
        classes
      end

      def step_to_i(step)
        step.to_s.split("_").last.to_i
      end

      def step?(step)
        current_step == step
      end

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

      def submit_text
        t("decidim.proposals.collaborative_drafts.new.send")
      end

      # Returns a string with the current step number and the total steps number
      #
      # step - A symbol of the target step
      def proposal_wizard_current_step
        content_tag(:span, class: "text-small") do
          out = t(:"decidim.proposals.proposals.wizard_steps.step_of",
                  current_step_num: step_to_i(current_step),
                  total_steps: 4)
          out << " ("
          out << content_tag(:a, t(:"decidim.proposals.proposals.wizard_steps.see_steps"), "data-toggle": "steps")
          out << ")"
          out
        end
      end
    end
  end
end
