# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserSerializer do
  let(:user) { Fabricate(:user, date_of_birth: "2017-04-05") }
  let!(:admin) { Fabricate(:admin) }

  context "when user is logged in" do
    let(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

    it "should include both the user's birthdate and cakedate" do
      expect(serializer.as_json[:birthdate]).to eq(user.date_of_birth)
      expect(serializer.as_json[:cakedate]).to eq(user.created_at.strftime("%Y-%m-%d"))
    end

    it "should not include the user's cakedate when private_cakeday_enabled is false" do
      SiteSetting.private_cakeday_enabled = false
      expect(serializer.as_json.has_key?(:cakedate)).to eq(false)
    end

    it "should not include the user's birthdate when private_cakeday_birthday_enabled is false" do
      SiteSetting.private_cakeday_birthday_enabled = false
      expect(serializer.as_json.has_key?(:birthdate)).to eq(false)
    end
  end

  context "when admin is logged in" do
    let(:serializer) { described_class.new(user, scope: Guardian.new(admin), root: false) }

    it "should include the user's full date of birth" do
      expect(serializer.as_json[:birthdate]).to eq(user.date_of_birth)
    end

    it "should include it even when the user keeps their birthday to themselves" do
      user.custom_fields["show_birthday_to_be_celebrated"] = false
      user.save_custom_fields

      expect(serializer.as_json[:birthdate]).to eq(user.date_of_birth)
    end

    it "should not include the user's birthdate when private_cakeday_birthday_enabled is false" do
      SiteSetting.private_cakeday_birthday_enabled = false

      expect(serializer.as_json.has_key?(:birthdate)).to eq(false)
    end
  end

  context "when another member is logged in" do
    fab!(:other, :user)

    let(:serializer) { described_class.new(user, scope: Guardian.new(other), root: false) }

    it "should mask the birthdate down to a day and month" do
      user.custom_fields["show_birthday_to_be_celebrated"] = true
      user.save_custom_fields

      expect(serializer.as_json[:birthdate]).to eq(Date.new(1904, 4, 5))
    end

    it "should follow the site default when the user never chose" do
      read = -> { described_class.new(user, scope: Guardian.new(other), root: false).as_json }

      expect(read.call[:birthdate]).to eq(nil)

      SiteSetting.private_cakeday_birthday_celebrate = true

      expect(read.call[:birthdate]).to eq(Date.new(1904, 4, 5))
    end

    it "should hide it entirely when the user opted out of being celebrated" do
      user.custom_fields["show_birthday_to_be_celebrated"] = false
      user.save_custom_fields

      expect(serializer.as_json[:birthdate]).to eq(nil)
    end
  end

  context "when user is not logged in" do
    let(:serializer) { described_class.new(user, scope: Guardian.new, root: false) }

    it "should not include the user's birthdate nor the cakedate" do
      expect(serializer.as_json.has_key?(:birthdate)).to eq(false)
      expect(serializer.as_json.has_key?(:cakedate)).to eq(false)
    end
  end
end
