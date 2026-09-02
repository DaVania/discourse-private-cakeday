# frozen_string_literal: true

require "rails_helper"

RSpec.describe PostSerializer do
  let(:user) { Fabricate(:user, date_of_birth: "2017-04-05") }
  let(:post) { Fabricate(:post, user: user) }

  context "when user is logged in" do
    let(:serializer) { described_class.new(post, scope: Guardian.new(user), root: false) }

    it "should include both the user's birthdate and cakedate" do
      expect(serializer.as_json[:user_birthdate]).to eq(user.date_of_birth)
      expect(serializer.as_json[:user_cakedate]).to eq(user.created_at.strftime("%Y-%m-%d"))
    end

    it "should not include the user's cakedate when private_cakeday_enabled is false" do
      SiteSetting.private_cakeday_enabled = false
      expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
    end

    it "should not include the user's birthdate when private_cakeday_birthday_enabled is false" do
      SiteSetting.private_cakeday_birthday_enabled = false
      expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
    end
  end

  context "when another member is logged in" do
    fab!(:other, :user)

    let(:serializer) { described_class.new(post, scope: Guardian.new(other), root: false) }

    it "should mask the author's birthdate down to a day and month" do
      user.custom_fields["show_birthday_to_be_celebrated"] = true
      user.save_custom_fields

      expect(serializer.as_json[:user_birthdate]).to eq(Date.new(1904, 4, 5))
    end

    it "should follow the site default when the author never chose" do
      read = -> { described_class.new(post, scope: Guardian.new(other), root: false).as_json }

      expect(read.call[:user_birthdate]).to eq(nil)
      expect(read.call[:user_celebrate]).to eq(false)

      SiteSetting.private_cakeday_birthday_celebrate = true

      expect(read.call[:user_birthdate]).to eq(Date.new(1904, 4, 5))
      expect(read.call[:user_celebrate]).to eq(true)
    end

    it "should hide it entirely when the author opted out of being celebrated" do
      user.custom_fields["show_birthday_to_be_celebrated"] = false
      user.save_custom_fields

      expect(serializer.as_json[:user_birthdate]).to eq(nil)
      expect(serializer.as_json[:user_celebrate]).to eq(false)
    end
  end

  context "when the post has no author left" do
    fab!(:admin)

    let(:serializer) { described_class.new(post, scope: Guardian.new(admin), root: false) }

    it "serializes without blowing up" do
      post.update!(user_id: nil, deleted_at: Time.zone.now)

      expect(serializer.as_json.key?(:user_birthdate)).to eq(false)
      expect(serializer.as_json[:user_celebrate]).to eq(nil)
    end
  end

  context "when user is not logged in" do
    let(:serializer) { described_class.new(post, scope: Guardian.new, root: false) }

    it "should not include the user's birthdate nor the cakedate" do
      expect(serializer.as_json.has_key?(:user_birthdate)).to eq(false)
      expect(serializer.as_json.has_key?(:user_cakedate)).to eq(false)
    end
  end
end
