import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import ComboBox from "discourse/select-kit/components/combo-box";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  userAge,
  userBirthdateText,
} from "discourse/plugins/discourse-private-cakeday/discourse/lib/cakeday";

// A birthday saved without a year carries this sentinel year.
const YEARLESS = 1904;

export default class UserDateOfBirthInput extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked year = null;
  @tracked month = null;
  @tracked day = null;
  @tracked hasBirthdate = false;
  @tracked hasAge = false;
  @tracked canControlVisibility = false;

  // `component.setProperties('hasBirthdateSaved', hasBirthdate)` in the old
  // connector was a no-op -- setProperties takes an object -- so this has
  // always been false and the staff shortcut below has never rendered. Kept as
  // it behaves today rather than silently switching that branch on.
  hasBirthdateSaved = false;

  constructor() {
    super(...arguments);

    const { model } = this.args;
    const { birthdate } = model;

    if (birthdate) {
      const parsed = moment(birthdate, "YYYY-MM-DD");
      this.year = parsed.year() === YEARLESS ? null : parsed.year();
      this.month = parsed.month() + 1;
      this.day = parsed.date().toString();
    }

    // Same rule as `updateBirthdate` below, and as the server-side check in
    // plugin.rb: with the year selector on, a birthday carrying the year-less
    // sentinel does not count. `year` is already null in that case.
    this.hasBirthdate = this.showYear ? this.year !== null : Boolean(birthdate);

    this.hasAge = this.year !== null;
    this.canControlVisibility = this.visibilityControllableFor(birthdate);

    // The model is seeded only once this render has finished: another
    // connector on this outlet (custom-ap-profile) has already read
    // `hasBirthdate` and `custom_fields` off the same model during this
    // render, and writing a value that was read in the same render trips
    // Ember's backtracking assertion, which aborts the rest of the page --
    // the Save button included. afterRender still runs before the next paint.
    schedule("afterRender", () => {
      // Nothing serializes `date_of_birth`, only `birthdate`, so the model
      // would otherwise submit an empty `date_of_birth` on every save and
      // silently wipe the stored date. Seed it so an untouched form saves
      // back what it shows, and an empty submission really does mean "the
      // user cleared the field".
      if (birthdate) {
        model.set("date_of_birth", birthdate);
      }

      model.set("hasBirthdate", this.hasBirthdate);

      // Seed the celebrate checkbox from the site default -- but only when
      // the checkbox is actually on screen. `custom_fields` rides along on
      // every profile save, so seeding it for a member who cannot see the
      // control writes their "choice" to the database without them ever
      // making one.
      if (
        model.custom_fields.show_birthday_to_be_celebrated === undefined &&
        this.canControlVisibility &&
        this.hasAge
      ) {
        model.set(
          "custom_fields.show_birthday_to_be_celebrated",
          this.siteSettings.private_cakeday_birthday_celebrate
        );
      }
    });

    // Whether the form is editable is decided once, from the saved birthday.
    // It must not follow the selectors, or the form would collapse under a
    // member half way through entering their first date.
    this.allowUserChangeBirthdate =
      this.isStaff || this.siteSettings.private_cakeday_birthday_allowchange;

    this.canChangeBirthdate =
      this.allowUserChangeBirthdate ||
      this.day === null ||
      this.month === null ||
      (this.year === null && this.showYear);

    this.userBirthdateText = userBirthdateText(this.currentUser, this.showYear);
  }

  get model() {
    return this.args.model;
  }

  get isStaff() {
    return this.currentUser?.staff;
  }

  get showYear() {
    return this.siteSettings.private_cakeday_birthday_show_year;
  }

  get months() {
    return moment.months().map((month, index) => {
      return { name: month, value: index + 1 };
    });
  }

  get days() {
    return [...Array(31).keys()].map((d) => (d + 1).toString());
  }

  get birthdateComplete() {
    return this.hasBirthdate && this.hasAge;
  }

  get showStaffShortcut() {
    return (
      this.hasBirthdateSaved &&
      this.siteSettings.private_cakeday_birthday_allowchange
    );
  }

  get showCelebrateCheckbox() {
    return this.canControlVisibility && this.hasAge;
  }

  visibilityControllableFor(date) {
    const minAge = this.siteSettings.private_cakeday_min_age_controlvisibility;
    return (minAge && userAge(date) >= minAge) || this.isStaff;
  }

  updateBirthdate() {
    let date = "";
    let hasBirthdate;

    if (this.year && this.month && this.day && this.showYear) {
      date = `${this.year}-${this.month}-${this.day}`;
      hasBirthdate = this.year > YEARLESS;
    } else if (this.month && this.day && !this.showYear) {
      date = `${YEARLESS}-${this.month}-${this.day}`;
      hasBirthdate = true;
    } else {
      hasBirthdate = false;
    }

    // The property that is being serialized when sending the update
    // request to the server is called `date_of_birth`
    this.model.set("date_of_birth", date);
    this.hasAge = this.year !== null && this.year > YEARLESS;
    this.hasBirthdate = hasBirthdate;
    this.model.set("hasBirthdate", hasBirthdate);
    this.canControlVisibility = this.visibilityControllableFor(date);
  }

  @action
  setDay(value) {
    this.day = value;
    this.updateBirthdate();
  }

  @action
  setMonth(value) {
    this.month = value;
    this.updateBirthdate();
  }

  @action
  setYear(event) {
    this.year = event.target.value;
    this.updateBirthdate();
  }

  <template>
    {{#if this.siteSettings.private_cakeday_birthday_enabled}}
      <a name="cakeday" aria-hidden="true"></a>
      <div class="control-group">
        <label class="control-label">{{i18n "user.date_of_birth.label"}}</label>
        <div class="controls">
          {{#if this.canChangeBirthdate}}
            {{#if this.siteSettings.private_cakeday_birthday_formatdmy}}
              <ComboBox
                @content={{this.days}}
                @value={{this.day}}
                @valueProperty={{null}}
                @nameProperty={{null}}
                @none="cakeday.dd"
                @options={{hash
                  clearable=true
                  autoInsertNoneItem=false
                  none="cakeday.dd"
                }}
                @onChange={{this.setDay}}
              />
              {{#if this.showYear}}
                -
              {{/if}}
              <ComboBox
                @content={{this.months}}
                @value={{this.month}}
                @valueAttribute="value"
                @valueProperty="value"
                @none="cakeday.mm"
                @options={{hash
                  clearable=true
                  autoInsertNoneItem=false
                  none="cakeday.mm"
                }}
                @onChange={{this.setMonth}}
              />
            {{else}}
              <ComboBox
                @content={{this.months}}
                @value={{this.month}}
                @valueAttribute="value"
                @valueProperty="value"
                @none="cakeday.mm"
                @options={{hash
                  clearable=true
                  autoInsertNoneItem=false
                  none="cakeday.mm"
                }}
                @onChange={{this.setMonth}}
              />
              {{#if this.showYear}}
                -
              {{/if}}
              <ComboBox
                @content={{this.days}}
                @value={{this.day}}
                @valueProperty={{null}}
                @nameProperty={{null}}
                @none="cakeday.dd"
                @options={{hash
                  clearable=true
                  autoInsertNoneItem=false
                  none="cakeday.dd"
                }}
                @onChange={{this.setDay}}
              />
            {{/if}}
            {{#if this.showYear}}
              -
              <input
                type="number"
                class="year"
                value={{this.year}}
                min="1905"
                max="2904"
                placeholder={{i18n "cakeday.yyyy"}}
                {{on "change" this.setYear}}
              />
            {{/if}}
            {{#if this.birthdateComplete}}
              &nbsp;
              {{dIcon "check"}}
            {{else}}
              {{#if this.siteSettings.private_cakeday_birthday_required}}
                {{#unless this.hasBirthdate}}
                  {{i18n "user.date_of_birth.required"}}
                {{/unless}}
              {{/if}}
            {{/if}}
          {{else}}
            {{i18n
              "user.date_of_birth.nochange"
              birthdate=this.userBirthdateText
            }}
          {{/if}}
          {{#if this.showStaffShortcut}}
            {{#if this.model.isStaff}}
              <div><a
                  href="/admin/users/{{this.model.id}}/{{this.model.username_lower}}"
                >{{dIcon "wrench"}}
                  {{i18n "admin.user.allow_change_by_user"}}</a></div>
            {{/if}}
          {{else}}
            {{#unless this.allowUserChangeBirthdate}}
              <label class="instructions">
                <div
                  class="warning"
                  style="background-color: var(--danger-low-mid); color: rgba(var(--always-black-rgb), 1);"
                >{{dIcon "exclamation-triangle"}}
                  {{i18n "user.date_of_birth.nochange_warn"}}</div>
              </label>
            {{/unless}}
          {{/if}}
          {{#if this.showCelebrateCheckbox}}
            <div style="margin-top: 10px;"><a
                name="show_birthday_to_be_celebrated"
                aria-hidden="true"
              ></a>
              <PreferenceCheckbox
                @labelKey="user.date_of_birth.show_birthday_to_be_celebrated"
                @checked={{this.model.custom_fields.show_birthday_to_be_celebrated}}
              />
              <label class="instructions">
                {{i18n "user.date_of_birth.always_visible_to_staff"}}
              </label>
              {{! The "limit age visibility to groups" checkbox and its group
                  chooser used to sit here. They never worked: the chooser
                  writes `groups_fullbirthday_visible`, which was never
                  registered as an editable user custom field, so the controller
                  strips it from every save and the column has no rows. Members
                  who ticked it believed they had restricted who could see their
                  age, and had not. Removed rather than left as a promise the
                  code does not keep -- see the commented-out
                  `shared_with_group?` in plugin.rb before reviving it. }}
            </div>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
