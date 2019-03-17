# frozen_string_literal: true

module Decidim
  module Proposals
    # Exposes Collaborative Drafts resource so users can view and create them.
    class CollaborativeDraftsController < Decidim::Proposals::ApplicationController
      helper Decidim::WidgetUrlsHelper
      # helper ProposalWizardHelper
      helper TooltipHelper

      include Decidim::ApplicationHelper
      include FormFactory
      include FilterResource
      include CollaborativeOrderable
      include Paginable

      helper_method :form_presenter

      helper_method :geocoded_collaborative_draft, :collaborative_draft
      before_action :collaborative_drafts_enabled?
      before_action :authenticate_user!, only: [:new, :create, :complete]
      before_action :retrieve_collaborative_draft, except: [:new]

      def index
        @collaborative_drafts = search
                                .results
                                .not_hidden
                                .includes(:category)
                                .includes(:scope)
                                .where.not(state: nil)

        @collaborative_drafts = paginate(@collaborative_drafts)
        @collaborative_drafts = reorder(@collaborative_drafts)
      end

      def show
        raise ActionController::RoutingError, "Not Found" unless retrieve_collaborative_draft
        @report_form = form(Decidim::ReportForm).from_params(reason: "spam")
        @request_access_form = form(RequestAccessToCollaborativeDraftForm).from_params({})
        @accept_request_form = form(AcceptAccessToCollaborativeDraftForm).from_params({})
        @reject_request_form = form(RejectAccessToCollaborativeDraftForm).from_params({})
      end

      # Controller actions related to WizardCreateStepForm
      def new
        enforce_permission_to :create, :collaborative_draft
        @step = :step_1
        @collaborative_draft = CollaborativeDraft
                               .from_all_author_identities(current_user)
                               .not_hidden.where(component: current_component)
                               .find_by(state: nil)

        if @collaborative_draft.present?
          redirect_to complete_collaborative_draft_path(@collaborative_draft)
        else
          @form = form(CollaborativeDraftForm).from_params({})
        end
      end

      def create
        enforce_permission_to :create, :collaborative_draft
        @step = :step_2
        @form = form(CollaborativeDraftForm).from_params(params)

        CreateCollaborativeDraft.call(@form, current_user) do
          on(:ok) do |collaborative_draft|
            flash[:notice] = I18n.t("create.success", scope: "decidim.proposals.collaborative_drafts")

            redirect_to compare_collaborative_draft_path(collaborative_draft)
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("create.error", scope: "decidim.proposals.collaborative_drafts")
            render :new
          end
        end
      end

      def compare
        @step = :step_2
        @similar_collaborative_drafts ||= Decidim::Proposals::SimilarCollaborativeDrafts
                                          .for(current_component, @collaborative_draft)
                                          .where.not(state: nil)

        if @similar_collaborative_drafts.blank?
          flash[:notice] = I18n.t("compare.no_similars_found", scope: "decidim.proposals.collaborative_drafts")
          redirect_to complete_collaborative_draft_path(@collaborative_draft)
        end
      end

      def complete
        enforce_permission_to :edit, :collaborative_draft, collaborative_draft: @collaborative_draft
        @step = :step_3
        @form = form(CollaborativeDraftForm).from_model(@collaborative_draft)
        @form.attachment = form(AttachmentForm).from_model(@collaborative_draft.attachments.first)
      end

      def edit
        enforce_permission_to :edit, :collaborative_draft, collaborative_draft: @collaborative_draft

        @form = form(CollaborativeDraftForm).from_model(@collaborative_draft)
        @form.attachment = form(AttachmentForm).from_model(@collaborative_draft.attachments.first)
      end

      def update
        enforce_permission_to :edit, :collaborative_draft, collaborative_draft: @collaborative_draft

        @form = form(CollaborativeDraftForm).from_params(params)
        UpdateCollaborativeDraft.call(@form, current_user, @collaborative_draft) do
          on(:ok) do |collaborative_draft|
            flash[:notice] = I18n.t("update.success", scope: "decidim.proposals.collaborative_drafts")
            if collaborative_draft.state.nil?
              redirect_to preview_collaborative_draft_path(collaborative_draft) and return
            end
            redirect_to Decidim::ResourceLocatorPresenter.new(collaborative_draft).path
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("update.error", scope: "decidim.proposals.collaborative_drafts")
            if collaborative_draft.state.nil?
              render :complete and return
            end
            render :edit
          end
        end
      end

      def open
        OpenCollaborativeDraft.call(@collaborative_draft, current_user) do
          on(:ok) do
            flash[:notice] = I18n.t("open.success", scope: "decidim.proposals.collaborative_drafts.collaborative_draft")
            redirect_to collaborative_draft_path(@collaborative_draft)
          end

          on(:invalid) do
            flash.now[:alert] = I18n.t("open.error", scope: "decidim.proposals.collaborative_drafts.collaborative_draft")
            render :complete
          end
        end
      end

      def destroy
        enforce_permission_to :edit, :collaborative_draft, collaborative_draft: @collaborative_draft
        @step = :step_3

        DestroyCollaborativeDraft.call(@collaborative_draft, current_user) do
          on(:ok) do
            flash[:notice] = I18n.t("destroy.success", scope: "decidim.proposals.collaborative_drafts")
            redirect_to new_collaborative_draft_path
          end

          on(:invalid) do
            flash[:alert] = I18n.t("destroy.error", scope: "decidim.proposals.collaborative_drafts")
            redirect_to complete_collaborative_draft_path(@collaborative_draft)
          end
        end
      end

      def preview; end

      def withdraw
        WithdrawCollaborativeDraft.call(@collaborative_draft, current_user) do
          on(:ok) do
            flash[:notice] = t("withdraw.success", scope: "decidim.proposals.collaborative_drafts.collaborative_draft")
          end

          on(:invalid) do
            flash.now[:alert] = t("withdraw.error", scope: "decidim.proposals.collaborative_drafts.collaborative_draft")
          end
        end
        redirect_to Decidim::ResourceLocatorPresenter.new(@collaborative_draft).path
      end

      def publish
        PublishCollaborativeDraft.call(@collaborative_draft, current_user) do
          on(:ok) do |proposal|
            flash[:notice] = I18n.t("publish.success", scope: "decidim.proposals.collaborative_drafts.collaborative_draft")
            redirect_to Decidim::ResourceLocatorPresenter.new(proposal).path
          end

          on(:invalid) do
            flash.now[:alert] = t("publish.error", scope: "decidim.proposals.collaborative_drafts.collaborative_draft")
            redirect_to Decidim::ResourceLocatorPresenter.new(@collaborative_draft).path
          end
        end
      end

      private

      def form_presenter
        @form_presenter ||= present(@form, presenter_class: Decidim::Proposals::CollaborativeDraftPresenter)
      end

      def collaborative_drafts_enabled?
        raise ActionController::RoutingError, "Not Found" unless component_settings.collaborative_drafts_enabled?
      end

      def retrieve_collaborative_draft
        @collaborative_draft = CollaborativeDraft.not_hidden.where(component: current_component).find_by(id: params[:id])
      end

      def geocoded_collaborative_draft
        @geocoded_collaborative_draft ||= search.results.not_hidden.select(&:geocoded?)
      end

      def search_klass
        CollaborativeDraftSearch
      end

      def default_filter_params
        {
          search_text: "",
          category_id: "",
          state: "open",
          scope_id: nil,
          related_to: ""
        }
      end
    end
  end
end
