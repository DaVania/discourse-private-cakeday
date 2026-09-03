# frozen_string_literal: true

require "rails_helper"

describe "Anniversaries and Birthdays" do
  describe "when not logged in" do
    it "should return the right response" do
      get "/cakeday/anniversaries.json"
      expect(response.status).to eq(403)
    end
  end

  describe "when logged in" do
    let(:time) { Time.zone.local(2016, 9, 30) }
    let(:current_user) { Fabricate(:user, created_at: time - 10.days) }

    before { sign_in(current_user) }

    it "should return 404 when viewing anniversaries and private_cakeday_enabled is false" do
      SiteSetting.private_cakeday_enabled = false

      get "/cakeday/anniversaries.json"
      expect(response.status).to eq(404)
    end

    it "should return 404 when viewing birthdays and private_cakeday_birthday_enabled is false" do
      SiteSetting.private_cakeday_birthday_enabled = false

      get "/cakeday/birthdays.json"
      expect(response.status).to eq(404)
    end

    describe "when viewing anniversaries" do
      it "should return the right payload" do
        freeze_time(time) do
          created_at = time - 1.year

          user1 = Fabricate(:user, created_at: created_at - 2.years)
          user2 = Fabricate(:user, created_at: created_at - 1.day)
          user3 = Fabricate(:user, created_at: created_at)
          user4 = Fabricate(:user, created_at: created_at + 1.day)
          user5 = Fabricate(:user, created_at: created_at + 2.days)
          user6 = Fabricate(:user, created_at: created_at + 1.year)

          get "/cakeday/anniversaries.json", params: { month: time.month }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user2.id, user1.id, user3.id]

          get "/cakeday/anniversaries.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user1.id, user3.id]

          get "/cakeday/anniversaries.json", params: { filter: "tomorrow" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user4.id]

          get "/cakeday/anniversaries.json", params: { filter: "upcoming" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user5.id]
        end
      end

      it "should account for the current user's timezone" do
        # Asia/Calcutta is +5.5 hours from UTC
        current_user.user_option.update!(timezone: "Asia/Calcutta")

        freeze_time(time) do
          created_at = time - 1.year

          user1 = Fabricate(:user, created_at: created_at + 5.hours)
          user2 = Fabricate(:user, created_at: created_at + 18.hours + 20.minutes)
          user3 = Fabricate(:user, created_at: created_at + 18.hours + 40.minutes)
          user4 = Fabricate(:user, created_at: created_at + 1.day + 2.hours)

          get "/cakeday/anniversaries.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to contain_exactly(user1.id, user2.id)

          get "/cakeday/anniversaries.json", params: { filter: "tomorrow" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to contain_exactly(user3.id, user4.id)
        end
      end
    end

    describe "when viewing birthdays" do
      let(:time) { Time.zone.local(2016, 9, 30) }

      # Only members who actively opted in are listed, so every fixture that is
      # expected to show up has to say so.
      def celebrant(celebrating: true, **attributes)
        user = Fabricate(:user, **attributes)
        user.custom_fields["show_birthday_to_be_celebrated"] = celebrating
        user.save_custom_fields
        user
      end

      it "should return the right payload" do
        freeze_time(time) do
          user1 = celebrant(date_of_birth: "1904-9-28")
          user2 = celebrant(date_of_birth: "1904-9-29")
          user3 = celebrant(date_of_birth: "1904-9-30")
          user4 = celebrant(date_of_birth: "1904-10-1")
          user5 = celebrant(date_of_birth: "1904-10-2")

          get "/cakeday/birthdays.json", params: { month: time.month }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user1.id, user2.id, user3.id]

          get "/cakeday/birthdays.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user3.id]

          get "/cakeday/birthdays.json", params: { filter: "tomorrow" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user4.id]

          get "/cakeday/birthdays.json", params: { filter: "upcoming" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user5.id]
        end
      end

      it "respects the prioritize_username_in_ux site setting" do
        freeze_time(time) do
          dob = "1904-9-30"
          user1 = celebrant(username: "alpha_zeta", name: "Zeta Alpha", date_of_birth: dob)
          user2 = celebrant(username: "zeta_alpha", name: "Alpha Zeta", date_of_birth: dob)
          user3 = celebrant(username: "beta_omega", name: "", date_of_birth: dob)

          SiteSetting.prioritize_username_in_ux = true

          get "/cakeday/birthdays.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user1.id, user3.id, user2.id]

          SiteSetting.prioritize_username_in_ux = false

          get "/cakeday/birthdays.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user2.id, user3.id, user1.id]
        end
      end

      describe "who shows up" do
        def birthdays_today_ids
          get "/cakeday/birthdays.json", params: { filter: "today" }
          JSON.parse(response.body)["birthdays"].map { |u| u["id"] }
        end

        it "lists only members who actively said yes, in either stored spelling" do
          freeze_time(time) do
            current_spelling = celebrant(date_of_birth: "1904-9-30")
            # Rows from before the field was registered as :boolean hold the
            # unnormalized string; `save_custom_fields` would rewrite it to
            # "t", so plant it the way the legacy data actually looks.
            legacy_spelling = Fabricate(:user, date_of_birth: "1904-9-30")
            UserCustomField.create!(
              user_id: legacy_spelling.id,
              name: "show_birthday_to_be_celebrated",
              value: "true",
            )
            Fabricate(:user, date_of_birth: "1904-9-30") # never chose
            celebrant(date_of_birth: "1904-9-30", celebrating: false) # opted out

            expect(birthdays_today_ids).to contain_exactly(current_spelling.id, legacy_spelling.id)
          end
        end

        it "requires an explicit yes even when the site default counts the undecided as celebrating" do
          SiteSetting.private_cakeday_birthday_celebrate = true

          freeze_time(time) do
            never_chose = Fabricate(:user, date_of_birth: "1904-9-30")
            opted_in = celebrant(date_of_birth: "1904-9-30")

            expect(never_chose.show_birthday_to_be_celebrated).to eq(true)
            expect(birthdays_today_ids).to eq([opted_in.id])
          end
        end

        it "shows staff everyone with a birthday, chosen or not" do
          sign_in(Fabricate(:admin))

          freeze_time(time) do
            never_chose = Fabricate(:user, date_of_birth: "1904-9-30")
            opted_out = celebrant(date_of_birth: "1904-9-30", celebrating: false)

            expect(birthdays_today_ids).to include(never_chose.id, opted_out.id)
          end
        end

        it "hides the no-birthday sentinel from staff as well" do
          sign_in(Fabricate(:admin))

          freeze_time(Time.zone.local(2016, 4, 5)) do
            hidden = Fabricate(:user, date_of_birth: DiscoursePrivateCakeday::HIDDEN_BIRTHDATE)

            expect(birthdays_today_ids).not_to include(hidden.id)
          end
        end

        it "leaves out members who asked for no birthday at all" do
          # Frozen on the sentinel's own day and month, so the date filter is not
          # what excludes them.
          freeze_time(Time.zone.local(2016, 4, 5)) do
            hidden = celebrant(date_of_birth: DiscoursePrivateCakeday::HIDDEN_BIRTHDATE)
            visible = celebrant(date_of_birth: "1904-4-5")

            expect(birthdays_today_ids).to eq([visible.id])
          end
        end
      end

      describe "what it discloses" do
        fab!(:listed_member) { Fabricate(:user, date_of_birth: "1983-9-30") }

        before do
          listed_member.custom_fields["show_birthday_to_be_celebrated"] = true
          listed_member.save_custom_fields
        end

        def listed_cakedate
          get "/cakeday/birthdays.json", params: { filter: "today" }
          JSON.parse(response.body)["birthdays"].find { |u| u["id"] == listed_member.id }[
            "cakedate"
          ]
        end

        it "masks the birth year for other members" do
          freeze_time(time) { expect(listed_cakedate).to eq("1904-09-30") }
        end

        it "shows members their own real date" do
          sign_in(listed_member)

          freeze_time(time) { expect(listed_cakedate).to eq("1983-09-30") }
        end

        it "shows the real date to staff" do
          sign_in(Fabricate(:admin))

          freeze_time(time) { expect(listed_cakedate).to eq("1983-09-30") }
        end
      end
    end
  end
end
