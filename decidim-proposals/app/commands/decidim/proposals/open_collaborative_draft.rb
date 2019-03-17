# frozen_string_literal: true

module Decidim
  module Proposals
    # A command with all the business logic when a user destroys a draft proposal.
    class OpenCollaborativeDraft < Rectify::Command
      # Public: Initializes the command.
      #
      # proposal     - The collaborative_draft to open.
      # current_user - The current user.
      def initialize(collaborative_draft, current_user)
        @collaborative_draft = collaborative_draft
        @current_user = current_user
      end

      # Executes the command. Broadcasts these events:
      #
      # - :ok when everything is valid and the proposal is deleted.
      # - :invalid if the collaborative_draft has a state.
      # - :invalid if the collaborative_draft's author is not the current user.
      #
      # Returns nothing.
      def call
        return broadcast(:invalid) unless @collaborative_draft.state.nil?
        return broadcast(:invalid) unless @collaborative_draft.created_by?(@current_user)

        @collaborative_draft.update(state: "open")

        broadcast(:ok, @collaborative_draft)
      end
    end
  end
end
