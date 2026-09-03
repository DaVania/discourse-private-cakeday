import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import anniversariesFixtures from "../fixtures/anniversaries";
import birthdaysFixtures from "../fixtures/birthdays";

acceptance("Cakeday - Sidebar with cakeday disabled", function (needs) {
  needs.user();

  needs.settings({
    private_cakeday_enabled: false,
    private_cakeday_birthday_enabled: false,
    navigation_menu: "sidebar",
  });

  test("anniversaries sidebar link is hidden", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.false(
      exists(".sidebar-section-link[data-link-name='anniversaries']"),
      "it does not display the anniversaries link in sidebar"
    );
  });

  test("birthdays sidebar link is hidden", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.false(
      exists(".sidebar-section-link[data-link-name='birthdays']"),
      "it does not display the birthdays link in sidebar"
    );
  });
});

acceptance("Cakeday - Sidebar with cakeday enabled", function (needs) {
  needs.user();

  needs.settings({
    private_cakeday_enabled: true,
    private_cakeday_birthday_enabled: true,
    navigation_menu: "sidebar",
  });

  needs.pretender((server, helper) => {
    server.get("/cakeday/anniversaries", () =>
      helper.response(cloneJSON(anniversariesFixtures))
    );
    server.get("/cakeday/birthdays", () =>
      helper.response(cloneJSON(birthdaysFixtures))
    );
  });

  test("clicking on anniversaries link", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='anniversaries']"
      ).textContent.trim(),
      i18n("anniversaries.title"),
      "displays the right text for the link"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-link-name='anniversaries']").title,
      i18n("anniversaries.title"),
      "displays the right title for the link"
    );

    assert.true(
      exists(
        ".sidebar-section-link[data-link-name='anniversaries'] .sidebar-section-link-prefix.icon .d-icon-birthday-cake"
      ),
      "displays the birthday-cake icon for the link"
    );

    await click(".sidebar-section-link[data-link-name='anniversaries']");

    assert.strictEqual(
      currentURL(),
      "/cakeday/anniversaries/today",
      "it navigates to the right page"
    );
  });

  test("clicking on birthdays link", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    assert.strictEqual(
      query(
        ".sidebar-section-link[data-link-name='birthdays']"
      ).textContent.trim(),
      i18n("birthdays.title"),
      "displays the right text for the link"
    );

    assert.strictEqual(
      query(".sidebar-section-link[data-link-name='birthdays']").title,
      i18n("birthdays.title"),
      "displays the right title for the link"
    );

    assert.true(
      exists(
        ".sidebar-section-link[data-link-name='birthdays'] .sidebar-section-link-prefix.icon .d-icon-birthday-cake"
      ),
      "displays the birthday-cake icon for the link"
    );

    await click(".sidebar-section-link[data-link-name='birthdays']");

    assert.strictEqual(
      currentURL(),
      "/cakeday/birthdays/today",
      "it navigates to the right page"
    );
  });
});
