# frozen_string_literal: true

require "spec_helper"

describe "Proposal", type: :system do
  include_context "with a component"

  let(:manifest_name) { "proposals" }
  let!(:scope) { create :scope, organization: organization }
  let!(:author) { create :user, :confirmed, organization: organization }
  let!(:user) { create :user, :confirmed, organization: organization }
  let(:participatory_process) { create(:participatory_process, :with_steps, organization: organization) }
  let!(:component) do
    create(:proposal_component,
           :with_creation_enabled,
           :with_collaborative_drafts_enabled,
           manifest: manifest,
           participatory_space: participatory_process,
           organization: organization)
  let(:component_path) { Decidim::EngineRouter.main_proxy(component) }

  context "when creating a new collaborative draft" do
    before do
      login_as user, scope: :user
      visit_component + "/collaborative_drafts/"
      click_link "New collaborative draft"
    end

    context "when in step_1: Create your proposal" do
      it "show current step_1 highlighted" do
        within ".wizard__steps" do
          expect(page).to have_css(".step--active", count: 1)
          expect(page).to have_css(".step--past", count: 0)
          expect(page).to have_css(".step--active.step_1")
        end
      end

      it "fill in title and body" do
        within ".card__content form" do
          fill_in :proposal_title, with: proposal_title
          fill_in :proposal_body, with: proposal_body
          find("*[type=submit]").click
        end
      end

      context "when the back button is clicked" do
        before do
          click_link "Back"
        end

        it "redirects to proposals_path" do
          expect(page).to have_content("PROPOSALS")
          expect(page).to have_content("New proposal")
        end
      end
    end

    context "when in step_2: Compare" do
      context "with similar results" do
        before do
          create(:proposal, title: "More sidewalks and less roads", body: "Cities need more people, not more cars", component: component)
          create(:proposal, title: "More sidewalks and less roadways", body: "Green is always better", component: component)
          visit_component
          click_link "New proposal"
          within ".new_proposal" do
            fill_in :proposal_title, with: proposal_title
            fill_in :proposal_body, with: proposal_body

            find("*[type=submit]").click
          end
        end

        it "show previous and current step_2 highlighted" do
          within ".wizard__steps" do
            expect(page).to have_css(".step--active", count: 1)
            expect(page).to have_css(".step--past", count: 1)
            expect(page).to have_css(".step--active.step_2")
          end
        end

        it "shows similar proposals" do
          expect(page).to have_content("SIMILAR PROPOSALS (2)")
          expect(page).to have_css(".card--proposal", text: "More sidewalks and less roads")
          expect(page).to have_css(".card--proposal", count: 2)
        end

        it "show continue button" do
          expect(page).to have_content("Continue")
        end

        it "does not show the back button" do
          expect(page).not_to have_link("Back")
        end
      end

      context "without similar results" do
        before do
          visit_component
          click_link "New proposal"
          within ".new_proposal" do
            fill_in :proposal_title, with: proposal_title
            fill_in :proposal_body, with: proposal_body

            find("*[type=submit]").click
          end
        end

        it "redirects to step_3: compare" do
          within ".section-heading" do
            expect(page).to have_content("COMPLETE YOUR PROPOSAL")
          end
          expect(page).to have_css(".edit_proposal")
        end

        it "shows no similar proposal found callout" do
          within ".flash.callout.success" do
            expect(page).to have_content("Well done! No similar proposals found")
          end
        end
      end
    end

    context "when in step_3: Complete" do
      before do
        visit_component
        click_link "New proposal"
        within ".new_proposal" do
          fill_in :proposal_title, with: proposal_title
          fill_in :proposal_body, with: proposal_body

          find("*[type=submit]").click
        end
      end

      it "show previous and current step_3 highlighted" do
        within ".wizard__steps" do
          expect(page).to have_css(".step--active", count: 1)
          expect(page).to have_css(".step--past", count: 2)
          expect(page).to have_css(".step--active.step_3")
        end
      end

      it "show form and submit button" do
        expect(page).to have_field("Title", with: proposal_title)
        expect(page).to have_field("Body", with: proposal_body)
        expect(page).to have_button("Preview")
      end

      it "can discard the proposal" do
        within ".card__content" do
          expect(page).to have_content("Discard the proposal")
          click_link "Discard the proposal"
        end

        page.accept_alert

        within_flash_messages do
          expect(page).to have_content "successfully"
        end
        expect(page).to have_css(".step--active.step_1")
      end

      it "renders a Preview button" do
        within ".card__content" do
          expect(page).to have_content("Preview")
        end
      end

      context "when the back button is clicked" do
        before do
          create(:proposal, title: proposal_title, component: component)
          click_link "Back"
        end

        it "redirects to step_3: compare" do
          expect(page).to have_content("SIMILAR PROPOSALS (1)")
        end
      end
    end

    context "when in step_4: Publish" do
      let!(:proposal_draft) { create(:proposal, :draft, users: [user], component: component, title: proposal_title, body: proposal_body) }

      before do
        visit component_path.preview_proposal_path(proposal_draft)
      end

      it "show current step_4 highlighted" do
        within ".wizard__steps" do
          expect(page).to have_css(".step--active", count: 1)
          expect(page).to have_css(".step--past", count: 3)
          expect(page).to have_css(".step--active.step_4")
        end
      end

      it "shows a preview" do
        expect(page).to have_content(proposal_title)
        expect(page).to have_content(user.name)
        expect(page).to have_content(proposal_body)
      end

      it "shows a publish button" do
        expect(page).to have_selector("button", text: "Publish")
      end

      it "shows a modify proposal link" do
        expect(page).to have_selector("a", text: "Modify the proposal")
      end

      context "when the back button is clicked" do
        before do
          click_link "Back"
        end

        it "redirects to step_3: compare" do
          expect(page).to have_content("COMPLETE YOUR PROPOSAL")
        end
      end
    end

    context "when a proposal draft exists for current users" do
      context "when visiting step_1: Create your proposal" do
        let!(:proposal_draft) { create(:proposal, :draft, users: [user], component: component) }

        before do
          visit component_path.new_proposal_path
        end

        it "redirects to step_3: compare" do
          within ".section-heading" do
            expect(page).to have_content("COMPLETE YOUR PROPOSAL")
          end
          expect(page).to have_content(proposal_draft.body)
        end
      end
    end
  end
end
