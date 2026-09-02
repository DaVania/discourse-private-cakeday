# Discourse Private Cakeday

A fork of [discourse-cakeday](https://github.com/discourse/discourse-cakeday) with
two extra features that the upstream (now bundled into Discourse core) doesn't
provide:

- **Year-of-birth storage** with age display
- **Group-based privacy controls** — users can choose to hide their birthdate
  from everyone except themselves, staff, and explicit allow-listed groups

![](example.png)
![](example2.png)

## Why a fork?

Discourse 3.6+ bundles its own `discourse-cakeday` plugin into core. The bundled
version doesn't store birth-year and doesn't filter age visibility based on
group membership — both features this fork adds. Since the bundled plugin
shares the upstream plugin name, this fork ships under a different name
(`discourse-private-cakeday`) so it can be installed alongside / instead of
core's version.

## Installing

This plugin **replaces** Discourse's built-in cakeday. Both can't be active at
the same time.

1. Disable the bundled plugin:
   Admin → Settings → search "cakeday" → uncheck `cakeday enabled`
2. Add to your `app.yml` under `plugins:`:
   ```yaml
   - git clone https://github.com/DaVania/discourse-private-cakeday.git
   ```
3. Rebuild the container
4. Enable: Admin → Settings → search "private cakeday" → check `private cakeday enabled`

See https://meta.discourse.org/t/install-a-plugin/19157/14 for general plugin
installation guidance.

## Site settings

All settings are prefixed `private_cakeday_*` so they don't collide with core's
`cakeday_*` namespace. Key options:

- `private_cakeday_enabled` — master switch
- `private_cakeday_birthday_celebrate` — whether a member who has never chosen
  counts as happy to have their birthday celebrated (default: off)
- `private_cakeday_birthday_show_year` — whether the year-of-birth selector
  appears in the user's date-of-birth preferences
- `private_cakeday_min_age_controlvisibility` — minimum age at which a user
  can choose to limit who sees their full birthdate (default: 18)
- `private_cakeday_show_age_to_groups` — groups that always see full
  birthdate regardless of the per-user visibility setting

## Requiring a date of birth

`private_cakeday_birthday_required` is enforced in two places, and it needs
both:

- **Client side** (`assets/javascripts/discourse/initializers/cakeday.js`) —
  the Save button on Preferences → Profile is blocked with a dialog until a
  birthdate is entered. This is the part members actually see.
- **Server side** (`plugin.rb`, prepended onto `UserUpdater#update`) — the same
  rule applied to the request itself, so the requirement does not evaporate the
  next time core reshuffles the preferences controller.

The client-side half is written against a moving target and has broken silently
before. It originally overrode the legacy `actions: { save() {…} }` hash; when
core turned `ProfileController` into a native class whose template invokes
`@action={{@controller.save}}`, that override stopped being called and the
requirement went unenforced for over a year without a single error anywhere.
It now uses the callback form of `api.modifyClass` and overrides the native
`@action save()` — **if core changes that again, the server-side check is what
still holds.**

Two things the client half deliberately does *not* do:

- It blocks only on an explicit `hasBirthdate === false`. That flag is written
  by the date-of-birth connector, and core hides the whole profile form —
  keeping the Save button — while it enforces its own required user fields
  (`needs_required_fields_check`). Blocking on a missing flag would trap the
  member on the one page they are allowed to visit, with nothing on screen that
  could satisfy the demand.
- It exempts staff.

### Blank birthdays are ignored, not obeyed

Nothing serializes `date_of_birth` to the client — only `birthdate` — so any
caller that saves the whole user object submits an empty `date_of_birth` and
silently wipes the stored date. That is not hypothetical: chat's
`disableFutureThreadTitlePrompts` calls `currentUser.save()` with no field list,
and the profile form itself did the same until the connector started seeding
`model.date_of_birth` from `birthdate` on load.

So while the requirement is on, the server-side check treats a blank
`date_of_birth` as "this caller does not know about the field":

- blank, and the member already has a birthday → the field is dropped from the
  update, the rest of it goes through, the stored date survives;
- blank, and the member has none → HTTP 422 with
  `private_cakeday.private_cakeday_birthday_required`;
- present → it has to satisfy the requirement (see below), and it is cast the
  same way the column casts it, so a string like `"Mar-5"` — which `Date.parse`
  accepts and ActiveRecord stores as NULL — cannot slip past as a birthday.

The cost is that a member cannot clear a birthday they are required to have.
Turn the requirement off and core's normal behaviour returns.

Other exemptions: staff, bots, staged users, anonymous shadow accounts, and any
update with no acting user.

One more exemption matters on both sides: while core is enforcing its *own*
required user fields (`needs_required_fields_check`), it hides the whole profile
form — birthday input included — keeps the Save button, and confines the member
to that page until the save succeeds. Blocking there would lock them out of the
forum with nothing on screen that could satisfy the demand, so neither half of
this plugin interferes until core's own gate has cleared.

### Year-less birthdays

With `private_cakeday_birthday_show_year` on, a day and month are not enough —
in the preferences form, in `hasBirthdate`, and in the request-level check
alike. Birthdays entered before the year selector existed are stored carrying a
`1904` sentinel year, and members holding one are treated as not having supplied
a birthday: the Profile tab blocks their save until they fill in the year, and a
submission carrying the sentinel is refused with 422.

The one place the sentinel is tolerated is a *blank* submission from a member
who already holds one. That is a caller that does not know about the field, not
the member setting anything, so their unrelated requests keep working and the
stored date survives. The preferences form — the only place they can actually
add the year — is what pushes them.

Turning the requirement on is retroactive in effect: existing members who have
no birthdate, or only a year-less one, cannot save the Profile tab until they
supply a full date.

## Who can see a birthday

One method decides it for the user card and the post stream alike —
`DiscoursePrivateCakeday.visible_birthdate(user, scope)` in `plugin.rb`:

- the member themselves and staff get the real date;
- everyone else gets day and month only, carrying the year-less `1904` sentinel,
  and only while the member is happy to have their birthday celebrated;
- a member stored with `1903-04-05` is hidden from everyone, staff included.

A member who has never touched the setting falls back to
`private_cakeday_birthday_celebrate`, which **defaults to off**: no choice means
no birthday on show. The server used to hardcode "yes" here and ignore the
setting entirely, so the admin's default was decorative — the checkbox on the
preferences form honoured it, the serializers did not.

Stored choices from before that fix could not be trusted either: the
preferences form used to seed the checkbox for anyone who had never touched it,
and `custom_fields` rides along on every profile save, so saving a bio was
enough to get an explicit opt-in written. The `WipeCelebrateChoices`
post-deploy migration therefore deletes every `show_birthday_to_be_celebrated`
row: everyone starts undecided and opts in deliberately or not at all. It is a
migration rather than a onceoff job on purpose — the rows must be gone before
the rebuilt app serves its first request, or sessions holding a pre-wipe
payload would write them straight back on their next profile save. (A browser
tab left open from before the rebuild can still do that until it reloads; that
window is accepted.) The form now only seeds the checkbox while it is actually
rendered.

The two serializers used to carry a copy of this each, and the post copy asked
the *Post* whether the viewer was the author, whether it was in a shared group,
and whether it was celebrating. A Post is never any of those things — but
`add_to_class(:post, …)` answers `true` when the field is absent, so the post
stream reported every author as celebrating and shipped the day and month of
members who had opted out. Keep both paths going through the one method.

**Group sharing is commented out.** It read `groups_fullbirthday_visible`,
which the preferences form does bind — but the field was never registered as
editable, so the controller strips it from every save and the column has no
rows anywhere. The preferences UI for it is still rendered and still inert;
wiring it back up means registering the field as editable (and deciding how it
relates to `limit_age_visibility_to_groups`) first.

### The birthdays page

`/cakeday/birthdays.json` lists **only members who actively opted in** — even
when `private_cakeday_birthday_celebrate` counts the undecided as celebrating
elsewhere. Being listed by name on a page is louder than the masked day and
month the serializers hand out, and nobody should land there without having
chosen it.

The opt-in test has to accept every spelling the column holds — `"t"` from
every current write path, plus literal `"true"` rows that predate the field
being registered as `:boolean`. Matching one of them hid most of the members
who had said yes.

The list also masks the birth year (`BirthdayUserSerializer`). The column behind
`cakedate` is the full date of birth, and the page only ever renders day and
month, so serving it verbatim handed every logged-in member the exact age of
everyone listed — the one thing the rest of the plugin masks.

## Co-existing with other plugins

`discourse-custom-ap-profile` (from version 0.2 onward, see
[the 2026.4 compat PR](https://github.com/DaVania/discourse-custom-ap-profile/pull/18))
detects this plugin and treats it as equivalent to bundled `discourse-cakeday`
for its PM age-gate and `add_to_group_by_min_age` automation scriptable.
Either plugin satisfies its `cakeday`-style dependency.

## Compatibility

- Discourse `main` / 2026.4+. Earlier versions may work but are not actively
  tested.
- Co-installable with `discourse-custom-ap-profile`.

## License

MIT
