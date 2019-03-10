# frozen_string_literal: true

module Decidim
  module Amendable
    # A command with all the business logic when a user starts amending a resource.
    class Create < Rectify::Command
      # Public: Initializes the command.
      #
      # form         - A form object with the params.
      # amendable    - The resource that is being amended.
      def initialize(form)
        @form = form
        @amendable = form.amendable
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid, together with the amend.
      # - :invalid if the form wasn't valid and we couldn't proceed.
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) if form.invalid?

        transaction do
          create_emendation!
          create_amendment!
          notify_amendable_authors_and_followers
        end

        broadcast(:ok)
      end

      private

      attr_reader :form

      def create_emendation!
        @emendation = Decidim.traceability.perform_action!(
          "publish",
          @amendable.amendable_type.constantize,
          form.current_user,
          visibility: "public-only"
        ) do
          emendation = @amendable.amendable_type.constantize.new(form.emendation_params)
          emendation.component = @amendable.component
          emendation.published_at = Time.current if @amendable.amendable_type == "Decidim::Proposals::Proposal"
          emendation.add_coauthor(form.current_user, user_group: form.user_group) if emendation.is_a?(Decidim::Coauthorable)
          emendation.save!
          emendation
        end
      end

      def create_amendment!
        @amendment = Decidim::Amendment.create!(
          amender: form.current_user,
          amendable: @amendable,
          emendation: @emendation,
          state: "evaluating"
        )
      end

      def affected_users
        @affected_users ||= begin
          if @amendable.is_a?(Decidim::Coauthorable)
            @amendable.authors
          else
            [@amendable.author]
          end
        end.uniq
      end

      def notify_amendable_authors_and_followers
        Decidim::EventsManager.publish(
          event: "decidim.events.amendments.amendment_created",
          event_class: Decidim::Amendable::AmendmentCreatedEvent,
          resource: @amendable,
          affected_users: affected_users,
          followers: @amendable.followers - affected_users,
          extra: {
            amendment_id: @amendment.id
          }
        )
      end
    end
  end
end
