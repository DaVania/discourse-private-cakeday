# frozen_string_literal: true

# One-time wipe of every stored show_birthday_to_be_celebrated choice, decided
# 2026-09-01 alongside flipping private_cakeday_birthday_celebrate to
# default-off.
#
# The rows could not be trusted as choices: while the old default was "yes",
# the preferences form seeded the checkbox for anyone who had never touched it,
# and `custom_fields` rides along on every profile save — so a member who
# merely saved their bio got an explicit opt-in written for them. There is no
# way to tell those rows from deliberate ones after the fact, so everyone
# starts over: nobody celebrates until they actively tick the box.
#
# This runs as a post-deploy migration — not a onceoff job — so the rows are
# gone before the rebuilt app serves a single request. A onceoff fires up to
# ten minutes after boot, and any session holding a pre-wipe payload would
# resubmit its stale `custom_fields` on the next profile save and write the
# row straight back.
class WipeCelebrateChoices < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM user_custom_fields
      WHERE name = 'show_birthday_to_be_celebrated'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
