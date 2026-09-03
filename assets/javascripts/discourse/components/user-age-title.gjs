import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class UserAgeTitle extends Component {
  get titleText() {
    return i18n("js.user.date_of_birth.label") + ": " + this.args.title;
  }

  <template>
    <div class="user-age-title" ...attributes>
      <div title={{this.titleText}}>
        {{@userage}}
      </div>
    </div>
  </template>
}
