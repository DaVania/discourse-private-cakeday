import { isEmpty } from "@ember/utils";
import { i18n } from "discourse-i18n";

export function cakeday(date) {
  return !isEmpty(date) && isSameDay(date, { anniversary: true });
}

export function birthday(date) {
  return !isEmpty(date) && isSameDay(date);
}

export function celebrate(u) {
  // The server serializes the defaulted answer as a top-level attribute on the
  // user and user-card payloads. The custom field is only present for
  // self/staff and never on cards, so reading it made every card "secret".
  return u.get("show_birthday_to_be_celebrated") === true;
}

export function userAge(dateOfBirth) {
  return dateOfBirth
    ? moment(dateOfBirth, "YYYY-MM-DD").year() !== 1904
      ? moment().diff(dateOfBirth, "years")
      : null
    : null;
}

export function userAgeTitle(user) {
  return user.birthdate && moment(user.birthdate, "YYYY-MM-DD").year() !== 1904
    ? userAge(user.birthdate) +
        " " +
        i18n("relative_time_picker.years", { count: userAge(user.birthdate) })
    : null;
}

export function userBirthdateTitle(user) {
  return user.birthdate && moment(user.birthdate, "YYYY-MM-DD").year() !== 1904
    ? moment(user.birthdate).format(i18n("dates.long_with_year_no_time"))
    : null;
}

export function userBirthdateText(user, show_year = true) {
  return user.birthdate
    ? moment(user.birthdate, "yyyy-mm-dd").year() !== 1904 && show_year
      ? moment(user.birthdate).format(i18n("dates.long_with_year_no_time"))
      : moment(user.birthdate).format(i18n("dates.long_no_year_no_time"))
    : null;
}

export function cakedayTitle(user, currentUser) {
  if (user.id === currentUser?.id) {
    return "user.anniversary.user_title";
  } else {
    return "user.anniversary.title";
  }
}

export function birthdayTitle(user, currentUser) {
  if (user.id === currentUser?.id) {
    return "user.date_of_birth.user_title";
  } else {
    return "user.date_of_birth.title";
  }
}

export function secretTitle(user, currentUser) {
  if (user.id === currentUser?.id) {
    return "user.date_of_birth.user_secret_title";
  } else {
    return "user.date_of_birth.secret_title";
  }
}

function isSameDay(dateString, opts) {
  const now = moment();
  const date = moment(dateString);

  if (opts?.anniversary) {
    if (now.format("YYYY") <= date.format("YYYY")) {
      return false;
    }
  }

  return now.format("MMDD") === date.format("MMDD");
}
