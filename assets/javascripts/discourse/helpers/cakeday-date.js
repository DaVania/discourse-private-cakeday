import { i18n } from "discourse-i18n";

export default function cakedayDate(val, { isBirthday }) {
  const date = moment(val);

  if (isBirthday) {
    return date.format(i18n("dates.full_no_year_no_time"));
  } else {
    return date.format(i18n("dates.full_with_year_no_time"));
  }
}
