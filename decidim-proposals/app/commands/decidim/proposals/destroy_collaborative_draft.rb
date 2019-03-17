# frozen_string_literal: true

module Decidim
  module Proposals
    # A command with all the business logic when a user destroys a
    # collaborative draft not yet open to collaboration
    class DestroyCollaborativeDraft < Rectify::Command
      # Public: Initializes the command.
      #
      # collaborative_draft     - The collaborative_draft to destroy.
      # current_user - The current user.
      def initialize(collaborative_draft, current_user)
        @collaborative_draft = collaborative_draft
        @current_user = current_user
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the collaborative draft is deleted.
      # - :invalid if the collaborative draft state is not nil.
      # - :invalid if the collaborative draft's creator author is not the current user.
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) unless @collaborative_draft.state.nil?
        return broadcast(:invalid) unless @collaborative_draft.authored_by?(@current_user)

        @collaborative_draft.destroy!

        broadcast(:ok, @collaborative_draft)
      end
    end
  end
end
