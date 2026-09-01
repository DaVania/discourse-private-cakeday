import Group from "discourse/models/group";
import {
  userAge,
  userBirthdateText,
} from "discourse/plugins/discourse-private-cakeday/discourse/lib/cakeday";

export default {
  setupComponent({ model }, component) {
    const { birthdate } = model;

    // Nothing serializes `date_of_birth`, only `birthdate`, so the model would
    // otherwise submit an empty `date_of_birth` on every save and silently wipe
    // the stored date. Seed it so an untouched form saves back what it shows,
    // and an empty submission really does mean "the user cleared the field".
    if (birthdate) {
      model.set("date_of_birth", birthdate);
    }

    const defyear = 1904;

    const months = moment.months().map((month, index) => {
      return { name: month, value: index + 1 };
    });

    const days = [...Array(31).keys()].map((d) => (d + 1).toString());

    const year = birthdate
      ? (moment(birthdate, "YYYY-MM-DD").year() !== defyear ? moment(birthdate, "YYYY-MM-DD").year() : null)
      : null;

    const month = birthdate
      ? moment(birthdate, "YYYY-MM-DD").month() + 1
      : null;

    const day = birthdate
      ? moment(birthdate, "YYYY-MM-DD").date().toString()
      : null;
    
    const isStaff = this.currentUser.staff;
    const showYear = model.siteSettings.private_cakeday_birthday_show_year;

    // Same rule as `updateBirthdate` below, and as the server-side check in
    // plugin.rb: with the year selector on, a birthday carrying the year-less
    // sentinel does not count. `year` is already null in that case.
    let hasBirthdate = showYear ? year !== null : Boolean(birthdate);
    model.set("hasBirthdate", hasBirthdate);

    let hasAge = year !== null;

    const allowUserChangeBirthdate = isStaff || model.siteSettings.private_cakeday_birthday_allowchange;
    let canChangeBirthdate = allowUserChangeBirthdate || (day === null || month === null || (year === null && showYear));
    const ageControlVisibility = model.siteSettings.private_cakeday_min_age_controlvisibility;
    let canControlVisibility = ageControlVisibility && userAge(birthdate) >= ageControlVisibility || isStaff;

    // Seed the celebrate checkbox from the site default — but only when the
    // checkbox is actually on screen. `custom_fields` rides along on every
    // profile save, so seeding it for a member who cannot see the control
    // writes their "choice" to the database without them ever making one.
    if (
      model.custom_fields.show_birthday_to_be_celebrated === undefined &&
      canControlVisibility &&
      hasAge
    ) {
      model.set(
        "custom_fields.show_birthday_to_be_celebrated",
        model.siteSettings.private_cakeday_birthday_celebrate
      );
    }
    
    let showGroups = hasAge && showYear && canControlVisibility;

    component.setProperties({
      year,
      months, month,
      days, day,
      canChangeBirthdate,
      canControlVisibility,
      showGroups,
      allowUserChangeBirthdate,
      hasAge,
      hasBirthdate,
    });
    component.setProperties('hasBirthdateSaved', hasBirthdate);

    const updateBirthdate = () => {
      let date = "";

      if (component.year && component.month && component.day && showYear) {
        date = `${component.year}-${component.month}-${component.day}`;
        hasBirthdate = component.year > 1904;
      }

      else if (component.month && component.day && !showYear) {
        date = `1904-${component.month}-${component.day}`;
        hasBirthdate = true;
      }

      else {
        hasBirthdate = false;
      }

      // The property that is being serialized when sending the update
      // request to the server is called `date_of_birth`
      model.set("date_of_birth", date);
      component.set("hasAge", component.year !== null && component.year > 1904);
      model.set("hasBirthdate", hasBirthdate);
      component.set("hasBirthdate", hasBirthdate);
      component.set("canControlVisibility", ageControlVisibility && userAge(date) >= ageControlVisibility || isStaff);;
    };

    Group.findAll().then((groups) => {
      this.set("TLandCustomGroups", groups.filter(function (g) {
    return g.id > 10}))});
    
    //needs an if siteSettings year required/available....
    //private_cakeday_birthday_show_year
    if (showYear) component.addObserver("year", updateBirthdate);
    component.addObserver("month", updateBirthdate);
    component.addObserver("day", updateBirthdate);
    component.set("userBirthdateText", userBirthdateText(this.currentUser, showYear));
  },
};
