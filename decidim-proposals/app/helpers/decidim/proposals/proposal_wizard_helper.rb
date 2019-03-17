# frozen_string_literal: true

module Decidim
  module Proposals
    # Simple helpers to handle markup variations for proposal wizard partials
    module ProposalWizardHelper
      # Returns the css classes used for the proposal wizard for the desired step
      #
      # step - A symbol of the target step
      # current_step - A symbol of the current step
      #
      # Returns a string with the css classes for the desired step
      def proposal_wizard_step_classes(step, current_step)
        step_i = step.to_s.split("_").last.to_i
        if step_i == proposal_wizard_step_number(current_step)
          %(step--active #{step} #{current_step})
        elsif step_i < proposal_wizard_step_number(current_step)
          %(step--past #{step})
        else
          %()
        end
      end

      # Returns the number of the step
      #
      # step - A symbol of the target step
      def proposal_wizard_step_number(step)
        step.to_s.split("_").last.to_i
      end

      # Returns the name of the step, translated
      #
      # step - A symbol of the target step
      def proposal_wizard_step_name(step)
        t("decidim.proposals.#{type_of}.wizard_steps.#{step}")
      end

      # Returns the page title of the given step, translated
      #
      # action_name - A string of the rendered action
      def proposal_wizard_step_title(action_name)
        step_title = case action_name
                     when "create"
                       "new"
                     when "update_draft"
                       "complete"
                     else
                       action_name
                     end

        t("decidim.proposals.#{type_of}.#{step_title}.title")
      end

      # Returns the list item of the given step, in html
      #
      # step - A symbol of the target step
      # current_step - A symbol of the current step
      def proposal_wizard_stepper_step(step, current_step)
        return if step == :step_4 && type_of == :collaborative_drafts
        content_tag(:li, proposal_wizard_step_name(step), class: proposal_wizard_step_classes(step, current_step).to_s)
      end

      # Returns the list with all the steps, in html
      #
      # current_step - A symbol of the current step
      def proposal_wizard_stepper(current_step)
        content_tag :ol, class: "wizard__steps" do
          %(
            #{proposal_wizard_stepper_step(:step_1, current_step)}
            #{proposal_wizard_stepper_step(:step_2, current_step)}
            #{proposal_wizard_stepper_step(:step_3, current_step)}
            #{proposal_wizard_stepper_step(:step_4, current_step)}
          ).html_safe
        end
      end

      # Returns a string with the current step number and the total steps number
      #
      # step - A symbol of the target step
      def proposal_wizard_current_step_of(step)
        current_step_num = proposal_wizard_step_number(step)
        content_tag :span, class: "text-small" do
          concat t(:"decidim.proposals.proposals.wizard_steps.step_of", current_step_num: current_step_num, total_steps: total_steps)
          concat " ("
          concat content_tag :a, t(:"decidim.proposals.proposals.wizard_steps.see_steps"), "data-toggle": "steps"
          concat ")"
        end
      end

      # Returns a boolean if the step has a help text defined
      #
      # step - A symbol of the target step
      def proposal_wizard_step_help_text?(step)
        translated_attribute(component_settings.try("proposal_wizard_#{step}_help_text")).present?
      end

      # Renders a user_group select field in a form.
      # form - FormBuilder object
      # name - attribute user_group_id
      #
      # Returns nothing.
      def user_group_select_field(form, name)
        selected = @form.user_group_id.presence
        user_groups = Decidim::UserGroups::ManageableUserGroups.for(current_user).verified
        form.select(
          name,
          user_groups.map { |g| [g.name, g.id] },
          selected: selected,
          include_blank: current_user.name
        )
      end

      private

      def total_steps
        case type_of
        when :collaborative_drafts
          3
        when :proposals
          4
        else
          4
        end
      end

      def wizard_aside_info_text
        t("wizard_aside.info", scope: "decidim.proposals.#{type_of}").html_safe
      end

      # Renders the back link except for step_2: compare
      #
      # The default `options` parameter is for :collaborative_drafts;
      # Since they are not created until the last step, we fill the form
      # fields with params instead of attributes.
      #
      # This is the same reason why some route helpers are singular for
      # proposals (member routes) and plural for collabs (collection routes)
      def wizard_aside_link_to_back(options = {})
        singular = type_of == :proposals

        url = case action_name.to_sym
              when :new, :compare
                send("#{type_of}_path")
              when :complete, :preview
                send("compare_#{type_of(singular)}_path", options)
              end

        link_to url do
          concat icon("chevron-left", class: "icon--small")
          concat wizard_aside_back_text(action_name.to_sym == :compare)
        end
      end

      # Returns different text for step_2: compare
      def wizard_aside_back_text(step_2 = false)
        scope = "decidim.proposals.#{type_of}.wizard_aside"
        # return t("exit", scope: scope).html_safe if step_2

        t("back", scope: scope).html_safe
      end

      # Returns the resource name
      def type_of(singular = false)
        return controller_name.singularize.to_sym if singular
        controller_name.to_sym
      end
    end
  end
end
