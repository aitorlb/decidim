# frozen_string_literal: true

module Decidim
  class ViewModel < Cell::ViewModel
    include ActionView::Helpers::TranslationHelper
    include ActionView::Helpers::FormOptionsHelper
    include Decidim::DecidimFormHelper
    include ::Cell::Translation
    include Decidim::ResourceHelper
    include Decidim::ScopesHelper
    include ActionController::Helpers
    include Decidim::ActionAuthorization
    include Decidim::ActionAuthorizationHelper
    include Decidim::ReplaceButtonsHelper

    delegate :current_organization, to: :controller

    def current_user
      context[:current_user]
    end

    private

    def decidim
      Decidim::Core::Engine.routes.url_helpers
    end
  end
end
