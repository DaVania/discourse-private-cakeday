# frozen_string_literal: true

module DiscoursePrivateCakeday
  class AnniversariesController < CakedayController
    requires_plugin PLUGIN_NAME

    before_action :ensure_private_cakeday_enabled

    def index
      # The users.created_at column is a "timestamp without timezone"
      # so we need to convert the "point in time" to the current user's timezone
      # for proper filtering and display (otherwise you might get off by ones
      # if you live in ~~the future~~ Fiji or in ~~the past~~ Hawaii)
      users, total, more_params =
        cakedays_by("created_at", at_least_one_year_old: true, apply_timezone: true)

      render_json_dump(
        anniversaries: serialize_data(users, CakedayUserSerializer),
        total_rows_anniversaries: total,
        load_more_anniversaries: anniversaries_path(more_params),
      )
    end

    private

    def ensure_private_cakeday_enabled
      raise Discourse::NotFound if !SiteSetting.private_cakeday_enabled
    end
  end
end
