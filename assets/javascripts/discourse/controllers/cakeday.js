import Controller from "@ember/controller";

export default class CakedayController extends Controller {
  get cakedayEnabled() {
    return this.siteSettings?.private_cakeday_enabled;
  }

  get birthdayEnabled() {
    return this.siteSettings?.private_cakeday_birthday_enabled;
  }
}
