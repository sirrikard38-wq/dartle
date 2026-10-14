# Online leaderboard (Firebase)

The leaderboard becomes shared by everyone who plays Dartle once a free Firebase
database is connected. Until then (and whenever the phone has no connection) the
leaderboard shows the scores on that device, as before.

It uses a **Firebase Realtime Database** and **anonymous sign-in**: nobody has to
make an account, and each device gets its own hidden id, so a player can only
change their own row.

## Setup (about 5 minutes, free)

1. Go to <https://console.firebase.google.com> and sign in with a Google account.
   **Create a project** (call it `dartle`). Google Analytics is not needed.
2. **Build → Realtime Database → Create Database.** Pick the location closest to
   your players, and choose **Start in locked mode**.
3. Open the **Rules** tab, replace everything with the contents of
   [`firebase/database.rules.json`](../firebase/database.rules.json) and press
   **Publish**. These rules let everyone read the board, let a player write only
   their own row, and check every field.
4. **Build → Authentication → Get started → Sign-in method → Anonymous →
   Enable → Save.**
5. **Project settings** (the gear) **→ General → Your apps → Add app → Web
   (`</>`)**. Give it a nickname (`Dartle`), register it, skip the hosting step,
   and copy the **`apiKey`** from the code it shows.
6. Back in **Realtime Database → Data**, copy the database address shown at the
   top (it looks like `https://dartle-xxxxx-default-rtdb.firebaseio.com`).
7. Put both values in [`web/online.json`](../web/online.json):

   ```json
   {
     "databaseUrl": "https://dartle-xxxxx-default-rtdb.firebaseio.com",
     "apiKey": "AIza..."
   }
   ```

   then push to `main`. The website and the Android app pick it up on the next
   build. (Both values are public identifiers, not passwords: the database rules
   are what protect the data.)

To switch the online board off again, empty both values.

## How it works

- Every checkout in Checkout calculator saves the player's totals under
  `/leaderboard/<their id>`: name, points, average time, accuracy, optimal %,
  attempts. A failed upload is sent again with the next result.
- The board shows the top 500 players by points, and the other rankings (average
  time, accuracy, optimal %) are computed from those.
- Each request waits at most 6 seconds; after that the screen shows the scores on
  the device instead, with a note saying so.
- Clearing the browser's data (or reinstalling the app) makes a new anonymous id,
  so that device starts a new row; the old row stays until it is deleted.

## Things to know

- Names and scores are **public** to every player (the leaderboard screen says so).
- There is no moderation. Someone can pick a rude name or send made-up numbers for
  their own row; the rules only keep the numbers in a sane range. To remove a
  row, open **Realtime Database → Data** in the Firebase console, find it and
  delete it (deleting the whole `leaderboard` node resets the board).
- The free Spark plan is far more than this needs.
- Code: `lib/src/leaderboard/online_leaderboard.dart` (all the logic, tested with
  a fake Firebase in `test/online_leaderboard_test.dart`), `lib/ui/online_setup.dart`
  (the browser's web requests and reading `online.json`).
