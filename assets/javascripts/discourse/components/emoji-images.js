import Component from "@ember/component";
import computed from "discourse/lib/decorators";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

export default Component.extend({
  classNames: ["emoji-images"],

  @computed("list")
  emojiHTML(list) {
    return list
      .split("|")
      .map((et) => emojiUnescape(`:${et}:`, { skipTitle: true }));
  },

  @computed("title")
  titleText(title) {
    return i18n(title);
  },
});
