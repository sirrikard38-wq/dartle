# Felgalizacija online (Firebase)

Each Felgalizacija can be shared between phones through a free Firebase
Realtime Database with **anonymous sign-in**. Nobody has to make an account:
each phone gets its own hidden id, which is the "account" a Felgalizacija's names
are synced to. Without it (or with no connection) every Felgalizacija simply
stays on its phone.

The project already exists (`dartle-a5145`, set in [`web/online.json`](../web/online.json));
the database and anonymous sign-in are switched on.

## Switching it on: publish the rules

In <https://console.firebase.google.com>, open the project, go to **Realtime
Database → Rules**, replace everything with the contents of
[`firebase/database.rules.json`](../firebase/database.rules.json) and press
**Publish**. The old `leaderboard` data (from when Dartle had a leaderboard)
can be deleted under **Realtime Database → Data**: the rules no longer let
anyone read or write it.

To switch everything online off again, empty both values in `web/online.json`.

## How it works

Each Felgalizacija is kept under `/felga/<key>`. The key is the SHA-256 hash
of the Felgalizacija's password, so only someone who knows the password can find
it. Nobody can list the Felgalizacije.

- **Joining:** typing the password of a Felgalizacija that is not on the phone
  finds it online. A popup then lists the names nobody has claimed yet. Picking
  one makes it this phone's name; **No** adds the player as a new name.
- **Writing:** each write carries `rev`, which must be one more than the value
  stored (1 for a new one), so a phone can never write over a newer copy.
  When two phones change it at once, the slower one fetches the newer copy and
  adds its own changes on top (`FelgaLedger.merged`): a +1 here and a +1 there
  make +2.
- **Checking:** the open Felgalizacija page checks for changes every 5 seconds,
  and right after every change.
- **Deleting** a Felgalizacija removes it from that phone only.
- **On localhost** (trying the app out on the computer) the app never talks to
  Firebase. A stand-in kept in the browser plays its part, so tests never write
  to the real database.
- Code: `lib/src/felga/felga_online.dart` (sync, merge, the Firebase and stand-in
  places, tested in `test/felga_online_test.dart`), `lib/src/online/firebase.dart`
  (sign-in, `online.json`), `lib/ui/online_setup.dart` (the browser's web requests).
- The free Spark plan is far more than this needs.
