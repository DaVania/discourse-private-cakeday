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

export default {
  setupComponent({ user }, component) {
    component.set("isCakeday", cakeday(user.cakedate));
    component.set("isBirthday", birthday(user.birthdate));
    component.set("isSecret", !celebrate(user));
    component.set("cakedayTitle", cakedayTitle(user, this.currentUser));
    component.set("birthdayTitle", birthdayTitle(user, this.currentUser));
    component.set("secretTitle", secretTitle(user, this.currentUser));

    const isStaff = this.currentUser && this.currentUser.staff;
    const isMe = this.currentUser && this.currentUser.id === user.id;
    const isAllowedByGroup = true;
    
    if (isMe || isStaff || isAllowedByGroup) {
      component.set("userAgeTitle", userAgeTitle(user));
      component.set("userBirthdateTitle", userBirthdateTitle(user));
    }
  },
};
