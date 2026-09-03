import Controller from "@ember/controller";
import computed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default Controller.extend({
  @computed
  title() {
    return i18n("anniversaries.today.title", {
      date: moment().add(1, "day").format(i18n("dates.full_no_year_no_time")),
    });
  },

  actions: {
    loadMore() {
      this.get("model").loadMore();
    },
  },
});
