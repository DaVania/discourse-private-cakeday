# frozen_string_literal: true

require "rails_helper"

describe "private_cakeday_birthday_required" do
  fab!(:user) { Fabricate(:user, date_of_birth: nil) }
  fab!(:admin)

  let(:error_message) { I18n.t("private_cakeday.private_cakeday_birthday_required") }

  before do
    SiteSetting.private_cakeday_enabled = true
    SiteSetting.private_cakeday_birthday_enabled = true
    SiteSetting.private_cakeday_birthday_required = true
    SiteSetting.private_cakeday_birthday_show_year = true
  end

  def update_profile(params)
    put "/u/#{user.username}.json", params: params
  end

  context "when the user is signed in as themselves" do
    before { sign_in(user) }

    it "rejects a profile save that submits an empty date of birth" do
      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(error_message)
      expect(user.reload.user_profile.bio_raw).to eq(nil)
    end

    it "rejects a birthday that cannot be parsed" do
      update_profile(bio_raw: "hello", date_of_birth: "not-a-date")

      expect(response.status).to eq(422)
      expect(user.reload.date_of_birth).to eq(nil)
    end

    it "rejects a birthday that only looks valid until the column casts it" do
      expect(Date.parse("Mar-5")).to be_present

      update_profile(bio_raw: "hello", date_of_birth: "Mar-5")

      expect(response.status).to eq(422)
      expect(user.reload.date_of_birth).to eq(nil)
    end

    it "accepts a profile save that carries a full date of birth" do
      update_profile(bio_raw: "hello", date_of_birth: "1990-3-5")

      expect(response.status).to eq(200)
      expect(user.reload.date_of_birth).to eq(Date.new(1990, 3, 5))
      expect(user.user_profile.bio_raw).to eq("hello")
    end

    it "rejects a year-less birthday while the year selector is on" do
      update_profile(bio_raw: "hello", date_of_birth: "1904-3-5")

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(error_message)
      expect(user.reload.date_of_birth).to eq(nil)
    end

    it "accepts a year-less birthday when the year selector is off" do
      SiteSetting.private_cakeday_birthday_show_year = false

      update_profile(bio_raw: "hello", date_of_birth: "1904-3-5")

      expect(response.status).to eq(200)
      expect(user.reload.date_of_birth).to eq(Date.new(1904, 3, 5))
    end

    it "rejects an untouched profile save from a member holding a legacy year-less birthday" do
      user.update!(date_of_birth: Date.new(1904, 3, 5))

      update_profile(bio_raw: "hello", date_of_birth: "1904-03-05")

      expect(response.status).to eq(422)
      expect(user.reload.date_of_birth).to eq(Date.new(1904, 3, 5))
    end

    it "leaves a legacy year-less birthday alone when the caller submits nothing" do
      user.update!(date_of_birth: Date.new(1904, 3, 5))

      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.date_of_birth).to eq(Date.new(1904, 3, 5))
      expect(user.user_profile.bio_raw).to eq("hello")
    end

    it "keeps an existing birthday instead of letting a blank value wipe it" do
      user.update!(date_of_birth: Date.new(1990, 3, 5))

      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.date_of_birth).to eq(Date.new(1990, 3, 5))
      expect(user.user_profile.bio_raw).to eq("hello")
    end

    it "stands aside while core is enforcing its own required user fields" do
      Fabricate(:user_field, requirement: "for_all_users")
      expect(user.reload.needs_required_fields_check?).to eq(true)

      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.user_profile.bio_raw).to eq("hello")
    end

    it "leaves updates that do not touch the birthday alone" do
      update_profile(bio_raw: "hello")

      expect(response.status).to eq(200)
      expect(user.reload.user_profile.bio_raw).to eq("hello")
    end

    it "does nothing when the requirement is turned off" do
      SiteSetting.private_cakeday_birthday_required = false

      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.user_profile.bio_raw).to eq("hello")
    end

    it "does nothing when birthdays are turned off" do
      SiteSetting.private_cakeday_birthday_enabled = false

      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.user_profile.bio_raw).to eq("hello")
    end

    it "does nothing when the plugin is turned off" do
      SiteSetting.private_cakeday_enabled = false

      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.user_profile.bio_raw).to eq("hello")
    end
  end

  context "when staff edit a user" do
    before { sign_in(admin) }

    it "lets staff save a profile without a date of birth" do
      update_profile(bio_raw: "hello", date_of_birth: "")

      expect(response.status).to eq(200)
      expect(user.reload.user_profile.bio_raw).to eq("hello")
    end
  end

  describe ".birthdate_verdict" do
    fab!(:actor, :user)

    def verdict(target, attributes)
      DiscoursePrivateCakeday.birthdate_verdict(actor, target, attributes)
    end

    it "reads string keys as well as symbols" do
      expect(verdict(user, "date_of_birth" => "")).to eq(:reject)
      expect(verdict(user, "date_of_birth" => "1990-3-5")).to eq(:allow)
    end

    it "exempts bots, staged users and anonymous shadow accounts" do
      expect(verdict(Discourse.system_user, date_of_birth: "")).to eq(:allow)
      expect(verdict(Fabricate(:user, staged: true), date_of_birth: "")).to eq(:allow)

      SiteSetting.allow_anonymous_mode = true
      anonymous = AnonymousShadowCreator.get(Fabricate(:user, trust_level: 1))
      expect(verdict(anonymous, date_of_birth: "")).to eq(:allow)
    end

    it "exempts an update with no actor" do
      expect(DiscoursePrivateCakeday.birthdate_verdict(nil, user, date_of_birth: "")).to eq(:allow)
    end
  end
end
