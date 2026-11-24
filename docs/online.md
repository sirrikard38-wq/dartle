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

Each Felgalizacija lives at its own address, `/felga/<64 random hex digits>`.
Only its members' phones know that address. Its password is a key to it: under
`/felga/<SHA-256 of the password>` there is a note `{"at": address}`. Nobody can
list the places, so only someone who knows the password finds the note.

The current password is also kept in the book (`pass`), so every member's phone
learns a new one. Changing the password writes a note for the new one and
closes the old note (`{"closed": true}`), so the old password leads nowhere,
while the members, who know the address, stay in. A Felgalizacija put online
before addresses existed sat at the place of its password. The first phone with
the newer version moves it to an address and leaves a note in its place.

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
- **Change password** (under the password in settings) makes a new random
  password. The members stay in.
- **Deleting** a Felgalizacija (asked once) removes it from that phone only.
  Online, that phone's name is taken out and the password changed. A phone whose
  name is taken out on another phone loses the Felgalizacija too.
- **On localhost** (trying the app out on the computer) the app never talks to
  Firebase. A stand-in kept in the browser plays its part, so tests never write
  to the real database.
- Code: `lib/src/felga/felga_online.dart` (sync, merge, the Firebase and stand-in
  places, tested in `test/felga_online_test.dart`), `lib/src/online/firebase.dart`
  (sign-in, `online.json`), `lib/ui/online_setup.dart` (the browser's web requests).
- The free Spark plan is far more than this needs.
