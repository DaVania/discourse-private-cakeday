import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

// Staff "unlock" a member's birthday by writing this date, which the profile
// form recognises and offers to clear.
const UNLOCKED = "1903-04-05";

export default class AdminUserCakeday extends Component {
  @service siteSettings;

  @tracked dateIsMagical = this.args.user?.birthdate === UNLOCKED;
  @tracked editingBirthdate = false;
  @tracked buffer = "";

  get user() {
    return this.args.user;
  }

  get birthdateRequired() {
    return this.siteSettings.private_cakeday_birthday_required;
  }

  get showUnlockedNotice() {
    return this.dateIsMagical && this.birthdateRequired;
  }

  // The old connector rendered {{admin-editable-field}}, which keeps its edit
  // state internally and hands it back through a two-way `editing=` binding.
  // Angle-bracket arguments are one-way, so the field is inlined here -- same
  // markup and classes as core's component -- to keep `editingBirthdate` in
  // step with the unlock button and the date-format hint below.
  @action
  toggleEditing(event) {
    event?.preventDefault();
    this.buffer = this.user?.birthdate;
    this.editingBirthdate = !this.editingBirthdate;
  }

  #putBirthdate(newDate) {
    const oldDate = this.user.birthdate;
    this.user.set("birthdate", newDate);

    const path = userPath(`${this.user.username.toLowerCase()}.json`);

    return ajax(path, {
      data: { date_of_birth: newDate },
      type: "PUT",
    }).catch((e) => {
      this.user.set("birthdate", oldDate);
      popupAjaxError(e);
    });
  }

  @action
  saveBirthdate() {
    const newDate = this.buffer;
    this.dateIsMagical = newDate === UNLOCKED;

    return this.#putBirthdate(newDate).finally(() => {
      this.editingBirthdate = false;
    });
  }

  @action
  unlockBirthdate() {
    this.dateIsMagical = true;
    return this.#putBirthdate(UNLOCKED);
  }

  @action
  setUnlockedBirthdate() {
    // The original also tried to set a placeholder through
    // `getElementsByTagName('input').placeholder`, which assigns to an
    // HTMLCollection and has never done anything. Dropped.
    this.user.set("birthdate", "");
    this.dateIsMagical = false;
    this.editingBirthdate = !this.editingBirthdate;
  }

  <template>
    <div class="display-row birthdate" id="userBirthdate">
      {{#if this.showUnlockedNotice}}
        <div class="field">{{i18n "user.date_of_birth.label"}}</div>
        <div class="value">
          {{i18n "admin.user.date_unlocked"}}
        </div>
        <div class="controls"></div>
      {{else}}
        <div class="field">{{i18n "user.date_of_birth.label"}}</div>
        <div class="value">
          {{#if this.editingBirthdate}}
            <DTextField
              @value={{this.buffer}}
              @autofocus="autofocus"
              @autocomplete="off"
            />
          {{else}}
            <a
              href
              {{on "click" this.toggleEditing}}
              class="inline-editable-field"
            >
              <span>{{this.user.birthdate}}</span>
            </a>
          {{/if}}
        </div>
        <div class="controls">
          {{#if this.editingBirthdate}}
            <DButton
              class="btn-default"
              @action={{this.saveBirthdate}}
              @label="admin.user_fields.save"
            />
            <a href {{on "click" this.toggleEditing}}>{{i18n "cancel"}}</a>
          {{else}}
            <DButton
              class="btn-default"
              @action={{this.toggleEditing}}
              @icon="pencil"
            />
          {{/if}}
        </div>
      {{/if}}
      {{#if this.birthdateRequired}}
        <div class="controls">
          {{#if this.dateIsMagical}}
            <DButton
              class="btn-default"
              @icon="pencil-alt"
              @action={{this.setUnlockedBirthdate}}
              @title="admin.user.unlock_birthdate"
            />
          {{else}}
            {{#unless this.editingBirthdate}}
              <DButton
                class="btn-default"
                @icon="unlock"
                @action={{this.unlockBirthdate}}
                @title="admin.user.unlock_birthdate"
              />
            {{/unless}}
          {{/if}}
        </div>
      {{/if}}
    </div>
    {{#if this.editingBirthdate}}
      <div class="display-row birthdate-description">
        <div class="field">{{i18n "admin.user.date_format_label"}}</div>
        <div class="value">{{i18n "admin.user.date_format"}}</div>
        <div class="controls"></div>
      </div>
    {{/if}}
  </template>
}
