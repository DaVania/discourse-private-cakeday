# frozen_string_literal: true

require "rails_helper"

describe "CI route diagnostic" do
  it "dumps routing state" do
    cakeday_routes =
      Rails.application.routes.routes.map { |r| r.path.spec.to_s }.select { |p| p.include?("cakeday") }

    diag = {
      eager_load: Rails.configuration.eager_load,
      plugins: Discourse.plugins.map(&:name).sort,
      plugin_enabled: SiteSetting.private_cakeday_enabled,
      cakeday_routes: cakeday_routes,
      engine_defined: defined?(::DiscoursePrivateCakeday::Engine).to_s,
      controller_defined: defined?(::DiscoursePrivateCakeday::AnniversariesController).to_s,
      engine_route_count: (
        begin
          ::DiscoursePrivateCakeday::Engine.routes.routes.size
        rescue StandardError => e
          "ERR #{e.class}"
        end
      ),
      mounted_app: Rails.application.routes.routes.map { |r| r.app.class.name }.tally.to_a.last(3),
    }

    expect(diag.to_json).to eq("DIAG")
  end
end
