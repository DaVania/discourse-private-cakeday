import { getOwner } from "@ember/owner";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import User from "discourse/models/user";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const SETTINGS = {
  private_cakeday_enabled: true,
  private_cakeday_birthday_enabled: true,
  private_cakeday_birthday_required: true,
  private_cakeday_birthday_show_year: true,
};

function profileFixture(birthdate) {
  const fixture = cloneJSON(userFixtures["/u/eviltrout.json"]);
  fixture.user.can_edit = true;
  fixture.user.birthdate = birthdate;
  return fixture;
}

// The acceptance helper's logged-in user is staff, and the gate exempts staff,
// so every test that is about a plain member has to demote it first.
function demoteToMember(context) {
  getOwner(context)
    .lookup("service:current-user")
    .setProperties({ admin: false, moderator: false });
}

// Returns a `saves` array the tests can inspect: one entry per PUT, holding the
// `date_of_birth` that actually went over the wire.
function trackSaves(needs, birthdate) {
  const saves = [];

  needs.hooks.beforeEach(() => (saves.length = 0));

  needs.pretender((server, helper) => {
    server.get("/u/eviltrout.json", () =>
      helper.response(profileFixture(birthdate))
    );

    server.put("/u/eviltrout.json", (request) => {
      saves.push(helper.parsePostData(request.requestBody).date_of_birth);
      return helper.response({ success: "OK", user: {} });
    });
  });

  return saves;
}

acceptance("Cakeday - birthdate required, none given", function (needs) {
  needs.user();
  needs.settings(SETTINGS);
  const saves = trackSaves(needs, null);

  test("the save is blocked", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    demoteToMember(this);

    await click(".save-changes");

    assert
      .dom(".dialog-body")
      .hasText(i18n("user.date_of_birth.is_required_error"));
    assert.deepEqual(saves, [], "nothing was sent to the server");
  });
});

acceptance("Cakeday - birthdate required, one given", function (needs) {
  needs.user();
  needs.settings(SETTINGS);
  const saves = trackSaves(needs, "1990-03-05");

  test("the save goes through and carries the stored birthday", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    demoteToMember(this);

    await click(".save-changes");

    assert.dom(".dialog-body").doesNotExist();
    assert.deepEqual(
      saves,
      ["1990-03-05"],
      "an untouched form saves the birthday back rather than blanking it"
    );
  });
});

acceptance("Cakeday - birthdate not required", function (needs) {
  needs.user();
  needs.settings({ ...SETTINGS, private_cakeday_birthday_required: false });
  const saves = trackSaves(needs, null);

  test("the save goes through without a birthdate", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    demoteToMember(this);

    await click(".save-changes");

    assert.dom(".dialog-body").doesNotExist();
    assert.strictEqual(saves.length, 1, "the save request was sent");
  });
});

acceptance("Cakeday - birthdate required, staff", function (needs) {
  needs.user();
  needs.settings(SETTINGS);
  const saves = trackSaves(needs, null);

  test("staff are not held to the requirement", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");

    await click(".save-changes");

    assert.dom(".dialog-body").doesNotExist();
    assert.strictEqual(saves.length, 1, "the save request was sent");
  });
});

acceptance(
  "Cakeday - birthdate required, core's required-fields form",
  function (needs) {
    needs.user();
    needs.settings(SETTINGS);
    const saves = trackSaves(needs, null);

    needs.hooks.beforeEach(() =>
      User.current().set("needs_required_fields_check", true)
    );

    test("the save is not blocked while core hides the birthday input", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");
      demoteToMember(this);

      assert
        .dom(".user-date-of-birth-input")
        .doesNotExist("core is showing its own required-fields form instead");

      await click(".save-changes");

      assert
        .dom(".dialog-body")
        .doesNotExist("blocking here would trap the member on this page");
      assert.strictEqual(saves.length, 1, "the save request was sent");
    });
  }
);

acceptance(
  "Cakeday - birthdate required, legacy year-less birthday",
  function (needs) {
    needs.user();
    needs.settings(SETTINGS);
    const saves = trackSaves(needs, "1904-03-05");

    test("the save is blocked until a year is supplied", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");
      demoteToMember(this);

      await click(".save-changes");

      assert
        .dom(".dialog-body")
        .hasText(i18n("user.date_of_birth.is_required_error"));
      assert.deepEqual(saves, [], "nothing was sent to the server");
    });
  }
);

acceptance("Cakeday - birthdate required, year selector off", function (needs) {
  needs.user();
  needs.settings({ ...SETTINGS, private_cakeday_birthday_show_year: false });
  const saves = trackSaves(needs, "1904-03-05");

  test("a year-less birthday is enough", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    demoteToMember(this);

    await click(".save-changes");

    assert.dom(".dialog-body").doesNotExist();
    assert.deepEqual(saves, ["1904-03-05"]);
  });
});

// The profile page's `model` is `currentUser`, which chat and other features
// save whole and unprompted, long after the member has left the page. What the
// birthday input leaves on that object is what goes over the wire then.
//
// These modules do not demote the member: no Save button is clicked, so the
// gate never runs and staff or not makes no difference. They run with the
// requirement off, the configuration in which the server does not protect the
// stored date either.
const UNGUARDED = { ...SETTINGS, private_cakeday_birthday_required: false };

async function saveFromAnotherPage(context) {
  await visit("/");
  await getOwner(context).lookup("service:current-user").save();
}

acceptance("Cakeday - half-edited birthday, one stored", function (needs) {
  needs.user();
  needs.settings(UNGUARDED);
  const saves = trackSaves(needs, "1990-03-05");

  test("clearing the year does not reach the server", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    await fillIn("input.year", "");

    await saveFromAnotherPage(this);

    assert.deepEqual(
      saves,
      ["1990-03-05"],
      "the stored date went, not a blank"
    );
  });

  test("a half-typed year does not reach the server", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    await fillIn("input.year", "19");

    await saveFromAnotherPage(this);

    assert.deepEqual(saves, ["1990-03-05"], "the stored date went, not 19-3-5");
  });

  test("emptying every field on purpose does reach the server", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    await fillIn("input.year", "");
    await click(selectKit(".birthday-month").clearButton());
    await click(selectKit(".birthday-day").clearButton());

    await saveFromAnotherPage(this);

    assert.deepEqual(saves, [""], "a deliberate clear is still submitted");
  });
});

acceptance("Cakeday - half-edited birthday, none stored", function (needs) {
  needs.user();
  needs.settings(UNGUARDED);
  const saves = trackSaves(needs, null);

  test("a year on its own does not reach the server", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    await fillIn("input.year", "1990");

    await saveFromAnotherPage(this);

    assert.deepEqual(
      saves,
      [undefined],
      "the key was absent from the payload; a blank would read as an empty string"
    );
  });

  test("a completed form does reach the server", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    const month = selectKit(".birthday-month");
    await month.expand();
    await month.selectRowByValue(3);
    const day = selectKit(".birthday-day");
    await day.expand();
    await day.selectRowByValue("5");
    await fillIn("input.year", "1990");

    await saveFromAnotherPage(this);

    assert.deepEqual(saves, ["1990-3-5"], "the new date went over the wire");
  });
});
