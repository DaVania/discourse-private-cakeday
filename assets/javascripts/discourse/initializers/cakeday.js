import I18n from "I18n";
import { action } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  birthday,
  cakeday,
} from "discourse/plugins/discourse-private-cakeday/discourse/lib/cakeday";

function initializeCakeday(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser) {
    return;
  }

  const store = api.container.lookup("service:store");
  store.addPluralization("anniversary", "anniversaries");

  const siteSettings = api.container.lookup("service:site-settings");

  // The Save button on the Profile tab calls `controller.save` directly
  // (`@action={{@controller.save}}`), so the override has to replace that
  // native `@action` method. Overriding the legacy `actions` hash silently
  // stops working the moment core turns a controller into a native class.
  //
  // `hasBirthdate` is written by the date-of-birth connector, so only a
  // definite `false` blocks the save: an absent flag means the input was never
  // rendered — as when core hides the whole form to enforce its own required
  // user fields — and blocking then would trap the member on a page that has
  // no way to satisfy the demand. The server-side check in plugin.rb is what
  // covers the gaps.
  api.modifyClass(
    "controller:preferences/profile",
    (Superclass) =>
      class extends Superclass {
        @action
        save() {
          if (
            siteSettings.private_cakeday_birthday_required &&
            !currentUser.staff &&
            !this.showEnforcedRequiredFieldsNotice &&
            this.model.hasBirthdate === false
          ) {
            this.set("saved", false);
            this.dialog.alert({
              message: I18n.t("user.date_of_birth.is_required_error"),
            });
            return;
          }

          return super.save(...arguments);
        }
      }
  );

  const emojiEnabled = siteSettings.enable_emoji;
  const cakedayEnabled = siteSettings.private_cakeday_enabled;
  const birthdayEnabled = siteSettings.private_cakeday_birthday_enabled;

  if (cakedayEnabled) {
    api.addTrackedPostProperties("user_cakedate");

    api.addPosterIcon((_, { user_cakedate, user_id }) => {
      if (cakeday(user_cakedate)) {
        let result = {};

        if (emojiEnabled) {
          result.emoji = siteSettings.private_cakeday_emoji;
        } else {
          result.icon = "birthday-cake";
        }

        if (user_id === currentUser?.id) {
          result.title = I18n.t("user.anniversary.user_title");
        } else {
          result.title = I18n.t("user.anniversary.title");
        }

        return result;
      }
    });
  }

  if (birthdayEnabled) {
    api.addTrackedPostProperties("user_birthdate");
    api.addTrackedPostProperties("user_celebrate");

    api.addPosterIcon((_, { user_birthdate, user_celebrate, user_id }) => {
      if (birthday(user_birthdate) && user_celebrate !== true && (user_id === currentUser?.id || currentUser?.staff)) {
        let result = {};

        if (emojiEnabled) {
          result.emoji = siteSettings.private_cakeday_secret_emoji;
        } else {
          result.icon = "shushing_face";
        }

        if (user_id === currentUser?.id) {
          result.title = I18n.t("user.date_of_birth.user_secret_title");
        } else {
          result.title = I18n.t("user.date_of_birth.secret_title");
        }

        return result;
      }
    });

    api.addPosterIcon((_, { user_birthdate, user_celebrate, user_id }) => {
      if (birthday(user_birthdate) && (user_celebrate === true || user_id === currentUser?.id || currentUser?.staff)) {
        let result = {};

        if (emojiEnabled) {
          result.emoji = siteSettings.private_cakeday_birthday_emoji;
        } else {
          result.icon = "birthday-cake";
        }

        if (user_id === currentUser?.id) {
          result.title = I18n.t("user.date_of_birth.user_title");
        } else {
          result.title = I18n.t("user.date_of_birth.title");
        }

        return result;
      }
    });
  }

  if (cakedayEnabled || birthdayEnabled) {
    if (
      siteSettings.navigation_menu !== "legacy" &&
      api.addCommunitySectionLink
    ) {
      if (cakedayEnabled) {
        api.addCommunitySectionLink({
          name: "anniversaries",
          route: "cakeday.anniversaries.today",
          title: I18n.t("anniversaries.title"),
          text: I18n.t("anniversaries.title"),
          icon: "birthday-cake",
        });
      }

      if (birthdayEnabled) {
        api.addCommunitySectionLink({
          name: "birthdays",
          route: "cakeday.birthdays.today",
          title: I18n.t("birthdays.title"),
          text: I18n.t("birthdays.title"),
          icon: "birthday-cake",
        });
      }
    } else {
      api.decorateWidget("hamburger-menu:generalLinks", () => {
        let route;

        if (cakedayEnabled) {
          route = "cakeday.anniversaries.today";
        } else if (birthdayEnabled) {
          route = "cakeday.birthdays.today";
        }

        return {
          route,
          label: "cakeday.title",
          className: "cakeday-link",
        };
      });
    }
  }
}

export default {
  name: "cakeday",

  initialize() {
    withPluginApi("0.1", (api) => initializeCakeday(api));
  },
};
