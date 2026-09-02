import DiscourseURL, { userPath } from "discourse/lib/url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default {
  setupComponent(args, component) {
    if (this.get("user.birthdate") === "1903-04-05") {
      this.set("dateIsMagical", true);
    }
  },
  actions: {
    saveBirthdate(newDate) {
      const oldDate = this.get("user.birthdate");
      this.set("user.birthdate", newDate);
      this.set("dateIsMagical", (newDate === "1903-04-05"));

      const path = userPath(`${this.get("user.username").toLowerCase()}.json`);

      return ajax(path, { data: { date_of_birth: newDate }, type: "PUT" })
        .catch((e) => {
          this.set("user.birthdate", oldDate);
          popupAjaxError(e);
        })
        .finally(() => this.toggleProperty("editingBirthdate"));
    },
    unlockBirthdate() {
      const oldDate = this.get("user.birthdate");
      const newDate = '1903-04-05';
      this.set("user.birthdate", newDate);
      this.set("dateIsMagical", true);

      const path = userPath(`${this.get("user.username").toLowerCase()}.json`);

      return ajax(path, { data: { date_of_birth: newDate }, type: "PUT" })
        .catch((e) => {
          this.set("user.birthdate", oldDate);
          popupAjaxError(e);
        });
    },
    setUnlockedBirthdate() {
      document.getElementById('userBirthdate').getElementsByTagName('input').placeholder='yyyy-mm-dd';
      const oldDate = this.get("user.birthdate");
      const newDate = '';
      this.set("user.birthdate", newDate);
      this.set("dateIsMagical", false);
      this.toggleProperty("editingBirthdate");
    },
  },
};
