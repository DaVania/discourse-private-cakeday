import Component from "@ember/component";
import computed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default Component.extend({
  classNames: ["user-age-title"],

  @computed("title")
  titleText(title) {
    return i18n('js.user.date_of_birth.label') + ': ' + title;
  },
});
