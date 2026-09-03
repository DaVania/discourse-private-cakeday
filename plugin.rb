# frozen_string_literal: true

# name: discourse-private-cakeday
# about: Show a birthday cake beside the user's name on their birthday and/or on the date they joined Discourse.
# version: 0.4
# authors: Alan Tan
# url: https://github.com/babylai/discourse-private-cakeday
# transpile_js: true

enabled_site_setting :private_cakeday_enabled

register_asset "stylesheets/cakeday.scss"
register_asset "stylesheets/emoji-images.scss"
register_asset "stylesheets/user-date-of-birth-input.scss"
register_asset "stylesheets/mobile/user-date-of-birth-input.scss"

register_svg_icon "birthday-cake" if respond_to?(:register_svg_icon)

after_initialize do
  module ::DiscoursePrivateCakeday
    PLUGIN_NAME = "discourse-private-cakeday"

    # Birthdays entered without a year are stored carrying this sentinel year.
    YEARLESS_SENTINEL_YEAR = 1904

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePrivateCakeday
    end

    # Cast the way the column will, so the check can never disagree with what
    # ends up in the database: `Date.parse` happily turns "Mar-5" into a date
    # that ActiveRecord then stores as NULL.
    def self.cast_date(value)
      return value if value.is_a?(::Date)
      return nil if value.blank?

      ::User.type_for_attribute(:date_of_birth).cast(value)
    end

    # Does this value satisfy `private_cakeday_birthday_required`? With the year
    # selector on, a day and month are not enough — the same rule the
    # preferences form applies.
    def self.full_birthdate?(value)
      date = cast_date(value)
      return false if date.nil?
      return true unless SiteSetting.private_cakeday_birthday_show_year

      date.year > YEARLESS_SENTINEL_YEAR
    end

    # A member who wants no birthday at all is stored carrying this date.
    HIDDEN_BIRTHDATE = "1903-04-05"

    # The birthdate `scope` is allowed to see on `user`:
    #   * the real date for the member themselves and for staff
    #   * day and month only — carrying the year-less sentinel — when they are
    #     happy to have their birthday celebrated
    #   * nothing otherwise
    #
    # Both the user and the post serializers go through here. They used to carry
    # a copy each, and the post copy asked the *post* whether it was staff, in a
    # group, or celebrating — so it answered "yes, celebrating" for everyone and
    # leaked the day and month of every member who had opted out.
    def self.visible_birthdate(user, scope)
      return nil unless SiteSetting.private_cakeday_birthday_enabled
      return nil if user.nil? || scope&.user.nil?

      date_of_birth = user.date_of_birth
      return nil if date_of_birth.blank? || date_of_birth.to_s == HIDDEN_BIRTHDATE
      return date_of_birth if scope.is_me?(user) || scope.is_staff?
      # return date_of_birth if shared_with_group?(user, scope)
      return nil unless user.show_birthday_to_be_celebrated

      ::Date.new(YEARLESS_SENTINEL_YEAR, date_of_birth.month, date_of_birth.day)
    end

    # Group sharing is disabled. It has never worked: the preferences form does
    # bind `groups_fullbirthday_visible`, but the field was never passed to
    # `register_editable_user_custom_field`, so UsersController strips it from
    # every save and the column has zero rows in every deployment. Re-enabling
    # it means registering it as editable (and deciding how it relates to
    # `limit_age_visibility_to_groups`) first.
    #
    # def self.shared_with_group?(user, scope)
    #   group_ids = user.custom_fields["groups_fullbirthday_visible"]
    #   return false if group_ids.blank?
    #
    #   scope.user.groups.where(id: group_ids.to_s.split("|")).exists?
    # end

    # What a member's preference means when they have never touched it. Only
    # `show_birthday_to_be_celebrated` has a site-wide default —
    # `private_cakeday_birthday_celebrate`, which the server used to ignore, so
    # every undecided member counted as celebrating no matter how the admin had
    # set it. The user card and the post stream both ask through here; the
    # birthdays list is deliberately stricter and takes only an explicit yes.
    def self.custom_field_default(field)
      return SiteSetting.private_cakeday_birthday_celebrate if
        field.to_s == "show_birthday_to_be_celebrated"

      true
    end

    # Callers pass either ActionController::Parameters or a plain Hash, and only
    # the former is indifferent about key types.
    def self.submitted_date_of_birth(attributes)
      return [false, nil] unless attributes.respond_to?(:key?)
      return [true, attributes[:date_of_birth]] if attributes.key?(:date_of_birth)
      return [true, attributes["date_of_birth"]] if attributes.key?("date_of_birth")

      [false, nil]
    end

    def self.without_date_of_birth(attributes)
      attributes.except(:date_of_birth, "date_of_birth")
    end

    # What should `UserUpdater` do with the birthday in this update?
    #
    #   :allow  — nothing to enforce here
    #   :keep   — the update would blank out a birthday the member already has;
    #             drop the field and let the rest of the update through
    #   :reject — the submitted birthday does not meet the requirement, or the
    #             member would be left without one at all
    #
    # `:keep` exists because a blank `date_of_birth` is almost never a member
    # deliberately erasing their birthday. Nothing serializes `date_of_birth` to
    # the client, so *any* caller that saves the whole user object — the Profile
    # tab, and `currentUser.save()` in
    # plugins/chat/.../chat-thread-title-prompt.js — submits an empty value and
    # silently wipes the stored date. Refusing to act on a blank value costs
    # members the ability to clear a birthday they are required to have anyway.
    #
    # A blank value is therefore never judged against the year rule: it is not
    # the member setting anything. Members holding a legacy year-less birthday
    # are pushed to add a year by the preferences form, which is the one place
    # they can actually do it — not by a 422 from an unrelated chat request.
    def self.birthdate_verdict(actor, user, attributes)
      return :allow unless SiteSetting.private_cakeday_enabled
      return :allow unless SiteSetting.private_cakeday_birthday_enabled
      return :allow unless SiteSetting.private_cakeday_birthday_required
      return :allow if actor.nil? || actor.staff?
      return :allow if user.nil? || user.bot? || user.staged? || user.anonymous?

      # Core hides the birthday input while it enforces its own required user
      # fields, and confines the member to that page until the save succeeds
      # (`ApplicationController#redirect_to_profile_if_required`). Holding them
      # to this requirement there would lock them out of the forum entirely, so
      # stand aside — while still dropping the blank `date_of_birth` that form
      # submits, so it cannot wipe a stored date on the way past.
      return :keep if user.needs_required_fields_check?

      submitted, value = submitted_date_of_birth(attributes)
      return :allow unless submitted
      return :allow if full_birthdate?(value)
      return :reject if value.present?

      user.date_of_birth.present? ? :keep : :reject
    end

    module UserUpdaterExtension
      def update(attributes = {})
        case ::DiscoursePrivateCakeday.birthdate_verdict(@actor, @user, attributes)
        when :reject
          @user.errors.add(
            :base,
            I18n.t("private_cakeday.private_cakeday_birthday_required"),
          )
          return false
        when :keep
          attributes = ::DiscoursePrivateCakeday.without_date_of_birth(attributes)
        end

        super(attributes)
      end
    end
  end

  # Server-side counterpart to the Save-button gate in
  # `initializers/cakeday.js`: the client check is a courtesy, this is the one
  # that still holds when the request does not come from that form.
  reloadable_patch { ::UserUpdater.prepend(::DiscoursePrivateCakeday::UserUpdaterExtension) }

  ::DiscoursePrivateCakeday::Engine.routes.draw do
    get "birthdays" => "birthdays#index"
    get "birthdays/:filter" => "birthdays#index"
    get "anniversaries" => "anniversaries#index"
    get "anniversaries/:filter" => "anniversaries#index"
  end

  Discourse::Application.routes.append { mount ::DiscoursePrivateCakeday::Engine, at: "/cakeday" }

  # None of these are reachable by autoloading — `app/jobs/onceoff/` does not map
  # onto the `Jobs::` namespace, and the engine's own controllers and serializers
  # are not on the autoload path either — so they have to be pulled in by hand.
  #
  # `require_relative`, not `load`: `load` re-executes the file on every call and
  # defines the constants outside Zeitwerk's bookkeeping, which under eager
  # loading leaves Rails unable to resolve the engine's controllers. That surfaces
  # as a routing failure — 404 on every /cakeday/* endpoint, with nothing naming
  # the real cause — which is exactly how it presented in CI while passing
  # locally. `require_relative` defines each constant once, deterministically.
  %w[
    app/jobs/onceoff/fix_invalid_date_of_birth
    app/jobs/onceoff/migrate_date_of_birth_to_users_table
    app/serializers/discourse_private_cakeday/cakeday_user_serializer
    app/serializers/discourse_private_cakeday/birthday_user_serializer
    app/controllers/discourse_private_cakeday/cakeday_controller
    app/controllers/discourse_private_cakeday/anniversaries_controller
    app/controllers/discourse_private_cakeday/birthdays_controller
  ].each { |path| require_relative path }

  # overwrite the user and user_card serializers to show
  # the cakes on the user card and on the user profile pages
  %i[user user_card].each do |serializer|
    add_to_serializer(serializer, :cakedate, include_condition: -> { scope.user.present? }) do
      timezone = scope.user.user_option&.timezone.presence || "UTC"
      object.created_at.in_time_zone(timezone).strftime("%Y-%m-%d")
    end

    add_to_serializer(
      serializer,
      :birthdate,
      include_condition: -> { SiteSetting.private_cakeday_birthday_enabled && scope.user.present? },
    ) { ::DiscoursePrivateCakeday.visible_birthdate(object, scope) }

    # What the client's `celebrate()` reads. It used to look for
    # `custom_fields.show_birthday_to_be_celebrated`, which never reaches the
    # user-card payload at all — so every card showed the "secret" icon, opted
    # in or not.
    add_to_serializer(
      serializer,
      :show_birthday_to_be_celebrated,
      include_condition: -> { SiteSetting.private_cakeday_birthday_enabled && scope.user.present? },
    ) { object.show_birthday_to_be_celebrated }
  end

  # overwrite the post serializer to show the cakes next to the
  # username in the posts stream

  add_to_serializer(
    :post,
    :user_cakedate,
    include_condition: -> { scope.user.present? && object.user&.created_at.present? },
  ) do
    timezone = scope.user.user_option&.timezone.presence || "UTC"
    object.user.created_at.in_time_zone(timezone).strftime("%Y-%m-%d")
  end

  add_to_serializer(
    :post,
    :user_birthdate,
    include_condition: -> do
      SiteSetting.private_cakeday_birthday_enabled && scope.user.present? &&
        object.user&.date_of_birth.present?
    end,
  ) { ::DiscoursePrivateCakeday.visible_birthdate(object.user, scope) }

  add_to_serializer(
    :post,
    :user_celebrate,
    include_condition: -> { SiteSetting.private_cakeday_birthday_enabled && scope.user.present? },
  ) { object.user&.show_birthday_to_be_celebrated }

  %w[
    show_birthday_to_be_celebrated
    limit_age_visibility_to_groups
  ].each do |field|
    User.register_custom_field_type(field, :boolean)
    DiscoursePluginRegistry.serialized_current_user_fields << field
    register_editable_user_custom_field field.to_sym

    add_to_class(:user, field.to_sym) do
      # `users#cards` preloads a fixed custom-field list that does not include
      # ours, and the preloaded proxy raises on any other key.
      if custom_fields_preloaded? && !custom_field_preloaded?(field)
        ::DiscoursePrivateCakeday.custom_field_default(field)
      else
        stored = custom_fields[field]
        stored.nil? ? ::DiscoursePrivateCakeday.custom_field_default(field) : stored
      end
    end
  end

  add_to_serializer(:admin_user, :birthdate?) do
    object&.date_of_birth
  end

end
