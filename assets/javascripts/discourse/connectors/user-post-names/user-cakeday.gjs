import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  birthday,
  birthdayTitle,
  cakeday,
  cakedayTitle,
  celebrate,
  secretTitle,
} from "discourse/plugins/discourse-private-cakeday/discourse/lib/cakeday";
import EmojiImages from "../../components/emoji-images";

export default class UserCakeday extends Component {
  @service currentUser;
  @service siteSettings;

  get model() {
    return this.args.model;
  }

  get isCakeday() {
    return cakeday(this.model?.cakedate);
  }

  get isBirthday() {
    return birthday(this.model?.birthdate);
  }

  get isSecret() {
    return !celebrate(this.model);
  }

  get cakedayTitle() {
    return cakedayTitle(this.model, this.currentUser);
  }

  get birthdayTitle() {
    return birthdayTitle(this.model, this.currentUser);
  }

  get secretTitle() {
    return secretTitle(this.model, this.currentUser);
  }

  <template>
    <div class="user-post-names-outlet user-cakeday" ...attributes>
      {{#if this.siteSettings.private_cakeday_birthday_enabled}}
        {{#if this.isBirthday}}
          {{#if this.isSecret}}
            <EmojiImages
              @list={{this.siteSettings.private_cakeday_secret_emoji}}
              @title={{this.secretTitle}}
            />
          {{/if}}
          <EmojiImages
            @list={{this.siteSettings.private_cakeday_birthday_emoji}}
            @title={{this.birthdayTitle}}
          />
        {{/if}}
      {{/if}}
      {{#if this.siteSettings.private_cakeday_enabled}}
        {{#if this.isCakeday}}
          <EmojiImages
            @list={{this.siteSettings.private_cakeday_emoji}}
            @title={{this.cakedayTitle}}
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
