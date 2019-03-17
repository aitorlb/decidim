# frozen_string_literal: true

module Decidim
  module Proposals
    # A command with all the business logic when a user updates a collaborative_draft.
    class UpdateCollaborativeDraft < Rectify::Command
      include AttachmentMethods
      include HashtagsMethods

      # Public: Initializes the command.
      #
      # form         - A form object with the params.
      # current_user - The current user.
      # collaborative_draft - the collaborative_draft to update.
      def initialize(form, current_user, collaborative_draft)
        @form = form
        @current_user = current_user
        @collaborative_draft = collaborative_draft
        @attached_to = collaborative_draft
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid, together with the collaborative_draft.
      # - :invalid if the form wasn't valid and we couldn't proceed.
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) if form.invalid?
        return broadcast(:invalid) unless collaborative_draft.editable_by?(current_user)

      if process_attachments?
        @collaborative_draft.attachments.destroy_all

        build_attachment
        return broadcast(:invalid) if attachment_invalid?
      end

        transaction do
                    if collaborative_draft.state.nil?
          update_closed_draft
          else
          update_collaborative_draft
        end
          create_attachment if process_attachments?
        end
        broadcast(:ok, collaborative_draft)
      end

      private

      attr_reader :form, :collaborative_draft, :current_user, :attachment

      def update_closed_draft
        @collaborative_draft.update!(attributes)
        @collaborative_draft.coauthorships.clear
        @collaborative_draft.add_coauthor(current_user, user_group: user_group)
      end

      def update_collaborative_draft
        Decidim.traceability.update!(
          @collaborative_draft,
          @current_user,
          attributes,
          visibility: "public-only"
        )
      end

      def attributes
        {
          title: title_with_hashtags,
          body: body_with_hashtags,
          category: form.category,
          scope: form.scope,
          address: form.address,
          latitude: form.latitude,
          longitude: form.longitude
        }
      end

      def user_group
        @user_group ||= Decidim::UserGroup.find_by(organization: current_user.organization, id: form.user_group_id)
      end
    end
  end
end
