import Component from "@glimmer/component";
import { service } from "@ember/service";
import {
  birthday,
  birthdayTitle,
  cakeday,
  cakedayTitle,
  celebrate,
  secretTitle,
  userAgeTitle,
  userBirthdateTitle,
} from "discourse/plugins/discourse-private-cakeday/discourse/lib/cakeday";
import EmojiImages from "../../components/emoji-images";
import UserAgeTitle from "../../components/user-age-title";

export default class UserCardCakeday extends Component {
  @service currentUser;
  @service siteSettings;

  get user() {
    return this.args.user;
  }

  get isCakeday() {
    return cakeday(this.user?.cakedate);
  }

  get isBirthday() {
    return birthday(this.user?.birthdate);
  }

  get isSecret() {
    return !celebrate(this.user);
  }

  get cakedayTitle() {
    return cakedayTitle(this.user, this.currentUser);
  }

  get birthdayTitle() {
    return birthdayTitle(this.user, this.currentUser);
  }

  get secretTitle() {
    return secretTitle(this.user, this.currentUser);
  }

  get userAgeTitle() {
    return userAgeTitle(this.user);
  }

  get userBirthdateTitle() {
    return userBirthdateTitle(this.user);
  }

  <template>
    <div class="user-card-post-names-outlet user-card-cakeday" ...attributes>
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
      {{#if this.siteSettings.private_cakeday_show_age_inline}}
        <UserAgeTitle
          @userage={{this.userAgeTitle}}
          @title={{this.userBirthdateTitle}}
        />
      {{/if}}
    </div>
  </template>
}
