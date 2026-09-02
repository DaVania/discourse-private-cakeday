# frozen_string_literal: true

module DiscoursePrivateCakeday
  class BirthdaysController < CakedayController
    requires_plugin PLUGIN_NAME

    before_action :ensure_birthday_enabled
    before_action :exclude_hidden_birthdays
    before_action :restrict_to_celebrated_for_non_staff

    def index
      users, total, more_params = cakedays_by("date_of_birth")

      render_json_dump(
        birthdays: serialize_data(users, BirthdayUserSerializer),
        total_rows_birthdays: total,
        load_more_birthdays: birthdays_path(more_params),
      )
    end

    private

    # Non-staff users only see members who have actively said yes. A member who
    # has never touched the setting is deliberately left out — even when
    # `private_cakeday_birthday_celebrate` counts the undecided as celebrating
    # elsewhere — because being listed by name on a page is a louder thing than
    # the masked day and month the serializers hand out, and nobody should land
    # there without having chosen it.
    #
    # Matching one spelling is not enough: every current write normalizes to
    # "t" (the field is registered :boolean), but rows from before that
    # registration still hold the literal "true", and both mean yes.
    #
    # This must narrow the set *before* cakedays_by counts and paginates,
    # otherwise total_rows_birthdays disagrees with the rows actually returned
    # and the client LoadMore loops forever.
    def restrict_to_celebrated_for_non_staff
      return if current_user.staff?

      celebrating =
        UserCustomField.where(name: "show_birthday_to_be_celebrated").true_fields.select(:user_id)

      @users = @users.where(id: celebrating)
    end

    # `visible_birthdate` hides this date from everyone, the member themselves
    # and staff included, so the list must not surface it either.
    def exclude_hidden_birthdays
      @users = @users.where.not(date_of_birth: ::DiscoursePrivateCakeday::HIDDEN_BIRTHDATE)
    end

    def ensure_birthday_enabled
      raise Discourse::NotFound if !SiteSetting.private_cakeday_birthday_enabled
    end
  end
end
