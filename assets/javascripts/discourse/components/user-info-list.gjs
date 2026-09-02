import DUserInfo from "discourse/ui-kit/d-user-info";
import cakedayDate from "../helpers/cakeday-date";

const UserInfoList = <template>
  <ul class="user-info-list">
    {{#each @users.content as |user|}}
      <li class="user-info-item">
        <DUserInfo @user={{user}}>
          <div>{{cakedayDate user.cakedate isBirthday=@isBirthday}}</div>
        </DUserInfo>
      </li>
    {{else}}
      <div class="user-info-empty-message"><p>{{yield}}</p></div>
    {{/each}}
  </ul>
</template>;

export default UserInfoList;
