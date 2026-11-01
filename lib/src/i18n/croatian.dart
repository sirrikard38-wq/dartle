/// The Croatian texts, by the English text they translate (see `I18n`).
///
/// Darts words that Croatian players say in English are kept: checkout, double,
/// triple, single, Bull, bust. A text that depends on a count has three forms
/// joined with `|` under the key `'English one|English other'`: for 1 (and 21,
/// 31 ...), for 2 to 4, and for the rest. The test `translations_test.dart`
/// checks that every text the code asks for is here, with the same `{pieces}`,
/// and that nothing here is left over.
const Map<String, String> croatian = {
  // ---------------------------------------------------------------- menus
  'Start': 'Kreni',
  'Favorites': 'Favoriti',
  'Leaderboard': 'Ljestvica',
  '180 Leaderboard': '180 Ljestvica',
  'Hi, {name}': 'Bok, {name}',
  'Welcome': 'Dobrodošli',
  'Enter your name...': 'Upiši svoje ime...',
  'Your name': 'Tvoje ime',
  'Enter your name to continue': 'Upiši ime za nastavak',
  'Continue': 'Nastavi',
  'Checkout calculator by PK Normal': 'Checkout kalkulator, autor PK Normal',
  'Checkout calculator': 'Checkout kalkulator',
  'Checkout practice': 'Checkout vježba',
  'Checkout input': 'Checkout unos',
  'Fill the boxes with the optimal checkout for the darts you have left.':
      'Popuni kućice optimalnim checkoutom za strelice koje ti ostaju.',
  'Choose your own optimal route.': 'Odaberi vlastitu optimalnu rutu.',
  'See the possibilities, enter a number.': 'Pogledaj mogućnosti, upiši broj.',

  // --------------------------------------------------------------- header
  'Current score': 'Trenutni rezultat',
  'Turn sound on': 'Uključi zvuk',
  'Turn sound off': 'Isključi zvuk',
  'Language: {name}. Press to change it.': 'Jezik: {name}. Pritisni za promjenu.',
  'Back': 'Natrag',
  'Back to the top': 'Natrag na vrh',

  // --------------------------------------------------------------- footer
  'Install': 'Instaliraj',
  'Install Dartle': 'Instaliraj Dartle',
  'Email': 'E-pošta',
  'Email {address}': 'E-pošta {address}',
  'Instagram, opens in a new tab': 'Instagram, otvara se u novoj kartici',
  'Tap the Share button in Safari, then Add to Home Screen.':
      'U Safariju dodirni gumb Dijeli, zatim Dodaj na početni zaslon.',
  'Android: open the browser menu, then tap Install app (or Add to Home screen).':
      'Android: otvori izbornik preglednika, zatim dodirni Instaliraj aplikaciju (ili Dodaj na početni zaslon).',
  'iPhone and iPad: tap the Share button in Safari, then Add to Home Screen.':
      'iPhone i iPad: u Safariju dodirni gumb Dijeli, zatim Dodaj na početni zaslon.',
  'Download the Android app (.apk)': 'Preuzmi Android aplikaciju (.apk)',
  'Close': 'Zatvori',

  // ------------------------------------------------------- number entry
  'UNDO': 'PONIŠTI',
  'ENTER': 'UNESI',
  'Delete the last digit': 'Obriši zadnju znamenku',
  'Press ENTER to play it.': 'Pritisni UNESI za igru.',
  'A number from 2 to 170.': 'Broj od 2 do 170.',
  'No number yet': 'Još nema broja',
  'Number {n}': 'Broj {n}',
  'Number pad': 'Tipkovnica s brojevima',
  'This number is impossible to checkout.': 'Za ovaj broj checkout je nemoguć.',
  'Next checkout': 'Sljedeći checkout',

  // ---------------------------------------------------------- game screen
  'Finish on a double or Bull in the given number of darts.':
      'Završi na doubleu ili Bullu u zadanom broju strelica.',
  'Finish on a double or Bull in the chosen number of darts.':
      'Završi na doubleu ili Bullu u odabranom broju strelica.',
  'Checkout {target}, {n} dart left|Checkout {target}, {n} darts left':
      'Checkout {target}, ostala {n} strelica|Checkout {target}, ostale {n} strelice|Checkout {target}, ostalo {n} strelica',
  '{target} to checkout, {n} dart left|{target} to checkout, {n} darts left':
      '{target} do checkouta, ostala {n} strelica|{target} do checkouta, ostale {n} strelice|{target} do checkouta, ostalo {n} strelica',
  'Your checkout, {n} dart left|Your checkout, {n} darts left':
      'Tvoj checkout, ostala {n} strelica|Tvoj checkout, ostale {n} strelice|Tvoj checkout, ostalo {n} strelica',
  'Replay - no clock, no points.': 'Ponavljanje - bez sata i bodova.',
  'Replay - the same number again.': 'Ponavljanje - isti broj opet.',
  'Only possible checkout.': 'Jedini mogući checkout.',
  'The lit areas are the optimal darts.': 'Osvijetljena područja su optimalne strelice.',
  'Started on {target}. The lit areas are the optimal darts.':
      'Počelo je na {target}. Osvijetljena područja su optimalne strelice.',
  'Press the darts to choose 2 or 3 darts.': 'Pritisni strelice za izbor 2 ili 3 strelice.',
  'Play {target} with {n} darts': 'Igraj {target} s {n} strelice',
  'left': 'ostalo',
  'over': 'preko',
  '{n} left': 'Ostalo {n}',
  'Over by {n}': 'Preko za {n}',
  'The last dart must be a double': 'Zadnja strelica mora biti double',

  // ------------------------------------------------------------- keyboard
  'Undo last dart': 'Poništi zadnju strelicu',
  'Undo last dart, {n} undo left|Undo last dart, {n} undos left':
      'Poništi zadnju strelicu, ostalo {n} poništavanje|Poništi zadnju strelicu, ostala {n} poništavanja|Poništi zadnju strelicu, ostalo {n} poništavanja',
  'NO CHECKOUT': 'NEMA CHECKOUTA',
  'No checkout: this number cannot be checked out':
      'Nema checkouta: ovaj broj se ne može zatvoriti',
  'Ring, left side': 'Prsten, lijeva strana',
  'Ring, right side': 'Prsten, desna strana',
  'Dart input': 'Unos strelica',
  'Single': 'Single',
  'Double': 'Double',
  'Triple': 'Triple',
  'Bull, 50': 'Bull, 50',
  'Outer bull, 25': 'Vanjski bull, 25',
  'Dartboard': 'Pikado ploča',
  'Dartboard. Press a number to throw {ring}.': 'Pikado ploča. Pritisni broj za {ring}.',
  'Dartboard. Press the area you want to throw.':
      'Pikado ploča. Pritisni područje u koje želiš baciti.',
  'already used': 'već iskorištena',
  'empty': 'prazna',
  'Dart {n}: {state}': 'Strelica {n}: {state}',
  'correct': 'točno',
  'in the route but in a different position': 'je u ruti, ali na drugom mjestu',
  'not in the route': 'nije u ruti',

  // --------------------------------------------------------------- result
  'Optimal!': 'Optimalno!',
  'Checkout!': 'Checkout!',
  'Bust': 'Bust',
  'Out of darts': 'Nema više strelica',
  'Not quite': 'Nije baš',
  'Good, but not in the given number of darts': 'Dobro, ali ne u zadanom broju strelica',
  'Also optimal': 'Također optimalno',
  'Also optimal: show every optimal way to check out {n}':
      'Također optimalno: prikaži sve optimalne načine za checkout {n}',
  'Also optimal: {route}': 'Također optimalno: {route}',
  'Only possibility': 'Jedina mogućnost',
  'Every optimal way to check out': 'Svaki optimalan način za checkout',
  'Every optimal way to check out {n}': 'Svaki optimalan način za checkout {n}',
  'Empty board: no darts used': 'Prazna ploča: nijedna strelica nije iskorištena',
  'No darts used': 'Nema iskorištenih strelica',
  'Your darts': 'Tvoje strelice',
  'Your darts: {route}': 'Tvoje strelice: {route}',
  'Optimal route': 'Optimalna ruta',
  'Optimal route: {route}': 'Optimalna ruta: {route}',
  'Route {route}': 'Ruta {route}',
  'You entered {sum}, not {target}': 'Upisao si {sum}, a ne {target}',
  'which is': 'što je',
  'Good job, no checkout here!': 'Bravo, ovdje nema checkouta!',
  'Replay checkout': 'Ponovi checkout',
  'Replay session': 'Ponovi sesiju',
  'Score: {points}': 'Rezultat: {points}',
  'No undos left, so the session is over.': 'Nema više poništavanja, pa je sesija gotova.',
  'TIME LEFT': 'PREOSTALO VRIJEME',
  'TIME USED': 'UTROŠENO VRIJEME',
  'SCORE': 'REZULTAT',
  'Score {total}, {points} this time. Press to see how it was worked out.':
      'Rezultat {total}, {points} ovaj put. Pritisni da vidiš kako je izračunat.',
  'How the score was worked out': 'Kako je izračunat rezultat',
  'Score now: {total}.': 'Rezultat sada: {total}.',

  // -------------------------------------------------- how the score works
  'Time left: {seconds}s. That is more than 0, so this checkout counts.':
      'Preostalo vrijeme: {seconds}s. To je više od 0, pa se ovaj checkout računa.',
  'It is checkout number {streak} in a row, so it scores {n} point.|It is checkout number {streak} in a row, so it scores {n} points.':
      'To je {streak}. checkout zaredom, pa vrijedi {n} bod.|To je {streak}. checkout zaredom, pa vrijedi {n} boda.|To je {streak}. checkout zaredom, pa vrijedi {n} bodova.',
  'Keep going: the next one in a row is worth {next}. A miss starts the count again from 0.':
      'Samo naprijed: sljedeći zaredom vrijedi {next}. Promašaj broji ponovno od 0.',
  'Time left: {seconds}s. The clock had run out, so no points this time.':
      'Preostalo vrijeme: {seconds}s. Sat je istekao, pa ovaj put nema bodova.',
  'Your streak of {streak} is kept, but it did not grow.':
      'Tvoj niz od {streak} je sačuvan, ali nije porastao.',
  'Finish with time left (above 0) to score again.':
      'Završi s preostalim vremenom (iznad 0) da opet osvojiš bodove.',
  'That was not right, so no points.': 'To nije bilo točno, pa nema bodova.',
  'Your streak is 0. Get one right to start it.': 'Tvoj niz je 0. Pogodi jedan da ga započneš.',
  'Your streak of {streak} starts again from 0.': 'Tvoj niz od {streak} kreće ponovno od 0.',
  'A replay does not score and has no clock.': 'Ponavljanje se ne boduje i nema sat.',

  // ------------------------------------------------------------ favorites
  'Favorite {route} - press to remove it': 'Favorit {route} - pritisni za uklanjanje',
  'Make {route} a favorite': 'Dodaj {route} u favorite',
  'Favorites for {n}': 'Favoriti za {n}',
  '{n} Dart|{n} Darts': '{n} strelica|{n} strelice|{n} strelica',
  'Mark a route with the dart in the "Also optimal" popup. Numbers with a favorite are white: press one to see them. Crossed out in red: no checkout.':
      'Označi rutu strelicom u prozoru „Također optimalno“. Brojevi s favoritom su bijeli: pritisni jedan da ih vidiš. Precrtano crveno: nema checkouta.',
  '{n}: no checkout': '{n}: nema checkouta',
  '{n}: no favorites': '{n}: nema favorita',
  '{n}: show its favorites': '{n}: prikaži favorite',

  // ---------------------------------------------------------- leaderboard
  'Total points': 'Ukupno bodova',
  'Average time': 'Prosječno vrijeme',
  'Accuracy': 'Točnost',
  'Optimal %': 'Optimalno %',
  'Rank by': 'Poredaj po',
  'Loading…': 'Učitavanje…',
  'No scores yet - be the first!': 'Još nema rezultata - budi prvi!',
  'Your name and scores are visible to all players.':
      'Tvoje ime i rezultati vidljivi su svim igračima.',
  'Scores on this device.': 'Rezultati na ovom uređaju.',

  // ---------------------------------------------------------- how to play
  'How to play': 'Kako igrati',
  'The basics': 'Osnove',
  'Order': 'Redoslijed',
  'What is optimal': 'Što je optimalno',
  'Aim': 'Ciljanje',
  'Bull safety': 'Sigurnost s Bullom',
  'The board': 'Ploča',
  'Colours': 'Boje',
  'Score': 'Rezultat',
  'The clock': 'Sat',
  'Undo': 'Poništi',
  'Choose your own darts to check the number out. The big number is what you still need. Before every dart the board lights up the optimal darts in grey and fades the rest, so you can see where to aim. Press anywhere on a number that has one lit area and it counts as that lit dart. When a number has two lit areas (say the triple and the single), press the exact area you want. Other numbers count as the exact area you press. You must finish on a double or Bull with the last of your darts; going below zero, leaving 1 or checking out with a dart still in hand is a miss, unless that double is lit. Most two-dart numbers can be played with two or three darts: before your second dart, press the boxes to choose. When a round is over, Replay checkout plays the same number again and Next checkout moves on. There is no clock and no score, and nothing is saved.':
      'Sam biraš strelice kojima zatvaraš broj. Veliki broj je ono što ti još treba. Prije svake strelice ploča osvijetli optimalne strelice sivo, a ostalo zatamni, da vidiš kamo ciljati. Pritisni bilo gdje na broju koji ima jedno osvijetljeno područje i računa se ta osvijetljena strelica. Kad broj ima dva osvijetljena područja (recimo triple i single), pritisni točno ono koje želiš. Ostali brojevi računaju se kao točno područje koje pritisneš. Zadnjom strelicom moraš završiti na doubleu ili Bullu; ići ispod nule, ostaviti 1 ili zatvoriti checkout s još jednom strelicom u ruci je promašaj, osim ako je taj double osvijetljen. Većina brojeva od dvije strelice može se igrati s dvije ili tri strelice: prije druge strelice pritisni kućice za izbor. Kad runda završi, Ponovi checkout igra isti broj opet, a Sljedeći checkout ide dalje. Nema sata ni rezultata i ništa se ne sprema.',
  'You get a number and always three boxes. A box that is crossed out is a dart already used, so it cannot be filled. A one-dart number has its first two boxes crossed out. A two-dart number has its left box crossed out - but half the time a two-dart number over 60 comes with all three boxes free. A three-dart number has nothing crossed out. Every free box has to be used: checking out with a box still free is a miss - unless it is an optimal route of fewer darts, which counts as right: "Good, but not in the given number of darts". Pick S, D or T (on either side of the board), then tap a number. The last free box is always a double or Bull. Your answer is checked the moment it is complete. Not every number can be checked out: if there is no checkout, press No checkout.':
      'Dobiješ broj i uvijek tri kućice. Prekrižena kućica je već iskorištena strelica pa se ne može popuniti. Broj od jedne strelice ima prve dvije kućice prekrižene. Broj od dvije strelice ima prekriženu lijevu kućicu - ali pola vremena broj od dvije strelice iznad 60 dolazi sa sve tri slobodne kućice. Broj od tri strelice nema ništa prekriženo. Svaka slobodna kućica mora se iskoristiti: zatvoriti checkout s još slobodnom kućicom je promašaj - osim ako je to optimalna ruta s manje strelica, što se računa kao točno: „Dobro, ali ne u zadanom broju strelica“. Odaberi S, D ili T (na bilo kojoj strani ploče), pa dodirni broj. Zadnja slobodna kućica uvijek je double ili Bull. Odgovor se provjerava čim je potpun. Nije svaki broj moguće zatvoriti: ako nema checkouta, pritisni Nema checkouta.',
  'The darts before the finisher are a combination: T20 T19 D8 is the same as T19 T20 D8. Only the last dart has a fixed place.':
      'Strelice prije završne su kombinacija: T20 T19 D8 je isto što i T19 T20 D8. Samo zadnja strelica ima fiksno mjesto.',
  'The fewest darts comes first. A single is far easier to hit than a double or a triple, so with the same number of darts the route with the most singles wins, and a double as a setup dart is the worst. Where no single can do it, triples T15 to T20 are used. With two darts up to 60 the first dart is a single that leaves a good double: D20, D18, D16, D14, D12, D10, D8, D6, D5, D4, D2 or D1. When two neighbouring singles on the board both do, only those count, because that is where you aim. If you miss and hit their triple or double, that counts too when it leaves a good double. So 48 is S8 D20 or S16 D16, and T8 D12, D16 D8 or D8 D16. With no such pair every single that leaves a good double counts, with its misses: 58 is S18 D20 or T18 D2. All of these are equally optimal.':
      'Najmanje strelica ide prvo. Single je puno lakše pogoditi nego double ili triple, pa uz isti broj strelica pobjeđuje ruta s najviše singleova, a double kao pripremna strelica je najgora. Gdje single ne može, koriste se tripleovi T15 do T20. S dvije strelice do 60 prva strelica je single koji ostavlja dobar double: D20, D18, D16, D14, D12, D10, D8, D6, D5, D4, D2 ili D1. Kad to rade dva susjedna singlea na ploči, računaju se samo oni, jer tamo ciljaš. Ako promašiš i pogodiš njihov triple ili double, i to se računa kad ostavlja dobar double. Tako je 48 S8 D20 ili S16 D16, te T8 D12, D16 D8 ili D8 D16. Bez takvog para računa se svaki single koji ostavlja dobar double, s njegovim promašajima: 58 je S18 D20 ili T18 D2. Sve su one jednako optimalne.',
  'With three darts on a two-dart number over 60, only aims are lit for the first dart: a number whose triple leaves a double and whose single leaves a two-dart finish (68: T14 leaves D13, S14 leaves 54). The best aim leaves a double with the single too (68: S18 leaves the Bull, T18 leaves D7). Every optimal route starts with an aim, followed by one of the routes of what is left (93: S19 leaves 74, then T20 D7) or by the other of the aim\'s single and triple and any double (74: S14 T14 D9; 64: S14 T14 D4). When two singles and the triple of a number all leave a double, any double, a dart of that number or of a neighbour counts too (64: S16 S16 D16, S16 S8 D20, S16 T8 D12). When the triple leaves a double you can halve, aim at that double: if you hit its single, the next double still finishes, so only that route counts (88: T20 leaves D14, then S14 and D7). When it leaves an odd double or the Bull, only a single that leaves a good double counts (88: T18 leaves 34, then S18 D8, S14 D10, S10 D12, S6 D14 or S2 D16). Under 60 three darts are your choice in Checkout practice and Checkout input. The aims are the numbers whose triple leaves a double and whose single, or two of its singles, leave one too (47: S7 leaves D20, T7 leaves D13; 48: S4 S4 leaves D20, T4 leaves D18). When the first dart leaves a double, that double is the best dart and it finishes even with a dart left. Its single is lit too when that leaves a double, so you see what to do after a miss (47: S7, then D20, or S20 and D10).':
      'S tri strelice na broju od dvije strelice iznad 60 za prvu strelicu svijetle samo ciljanja: broj čiji triple ostavlja double, a single ostavlja zatvaranje u dvije strelice (68: T14 ostavlja D13, S14 ostavlja 54). Najbolje ciljanje ostavlja double i singleom (68: S18 ostavlja Bull, T18 ostavlja D7). Svaka optimalna ruta počinje ciljanjem, a slijedi jedna od ruta za ostatak (93: S19 ostavlja 74, pa T20 D7) ili drugi od singlea i triplea tog broja pa bilo koji double (74: S14 T14 D9; 64: S14 T14 D4). Kad dva singlea i triple nekog broja ostavljaju double, bilo koji double, računa se i strelica tog broja ili njegova susjeda (64: S16 S16 D16, S16 S8 D20, S16 T8 D12). Kad triple ostavlja double koji se može prepoloviti, ciljaj taj double: ako pogodiš njegov single, sljedeći double i dalje zatvara, pa se računa samo ta ruta (88: T20 ostavlja D14, pa S14 i D7). Kad ostavlja neparan double ili Bull, računa se samo single koji ostavlja dobar double (88: T18 ostavlja 34, pa S18 D8, S14 D10, S10 D12, S6 D14 ili S2 D16). Ispod 60 tri strelice su tvoj izbor u načinima Checkout vježba i Checkout unos. Ciljanja su brojevi čiji triple ostavlja double, a to rade i njegov single ili dva njegova singlea (47: S7 ostavlja D20, T7 ostavlja D13; 48: S4 S4 ostavlja D20, T4 ostavlja D18). Kad prva strelica ostavlja double, taj double je najbolja strelica i zatvara čak i ako ti ostane strelica. Svijetli i njegov single kad on ostavlja double, da vidiš što napraviti nakon promašaja (47: S7, pa D20, ili S20 i D10).',
  'With two darts left on 61 to 70, aim at the number that is 50 less than what is left. Say 61 is left: the single 11 leaves exactly 50, so throw the triple T11 and then D14, or the single S11 and then the Bull. These are the optimal routes. If you aim at the triple and hit the single, you still have the Bull. For three darts the first dart should leave 55 to 70 (119: T19 leaves 62, then T12 D13 or S12 Bull).':
      'S dvije strelice preostale na 61 do 70, ciljaj broj koji je za 50 manji od onoga što je ostalo. Recimo da je ostalo 61: single 11 ostavlja točno 50, pa baci triple T11 i zatim D14, ili single S11 i zatim Bull. To su optimalne rute. Ako ciljaš triple, a pogodiš single, još uvijek imaš Bull. Za tri strelice prva strelica treba ostaviti 55 do 70 (119: T19 ostavlja 62, pa T12 D13 ili S12 Bull).',
  'Pick S, D or T (single, double or triple - the buttons on both sides of the board are the same, use either hand) and the matching rings of the board turn grey; everything else goes dark. The board is drawn to real proportions, so the doubles and triples are thin: press anywhere in a number\'s wedge and the ring you picked is thrown at that number. Each press leaves a see-through circle on that ring, so you can see how the checkout looks on the board.':
      'Odaberi S, D ili T (single, double ili triple - gumbi s obje strane ploče su isti, koristi koju ruku želiš) i odgovarajući prstenovi ploče postaju sivi; sve ostalo se zatamni. Ploča je nacrtana u pravim omjerima, pa su doubleovi i tripleovi tanki: pritisni bilo gdje u isječku broja i odabrani prsten baca se na taj broj. Svaki pritisak ostavlja prozirni krug na tom prstenu, pa vidiš kako checkout izgleda na ploči.',
  'The boxes stay plain while you play. After the checkout, each dart flips to a colour: white means it belongs in the best route, light pink means it does not, and grey means the right dart in the wrong place. Press "Also optimal" to see every optimal route on its own board. Press the little dart in the corner of a board to make that route a favorite: it fills in white, comes first next time, and is kept under Favorites in the menu. A number with only one optimal route has it as a favorite from the start. Your own checkout under "Your darts" can be a favorite too, when it ends on a double and adds up to the number - optimal or not.':
      'Kućice ostaju obične dok igraš. Nakon checkouta svaka se strelica okrene u boju: bijela znači da pripada najboljoj ruti, svijetloružičasta da ne pripada, a siva da je prava strelica na krivom mjestu. Pritisni „Također optimalno“ da vidiš svaku optimalnu rutu na njezinoj ploči. Pritisni malu strelicu u kutu ploče da tu rutu učiniš favoritom: ispuni se bijelo, sljedeći put je prva i čuva se pod Favoriti u izborniku. Broj s samo jednom optimalnom rutom ima je kao favorita od početka. I tvoj vlastiti checkout pod „Tvoje strelice“ može biti favorit, kad završava na doubleu i zbroj je jednak broju - optimalan ili ne.',
  'A correct checkout with time left on the clock scores as many points as you have checkouts in a row: 1, then 2, then 3. A miss costs nothing but the count starts again from 0. If the clock has run out, a right answer scores 0 but keeps your streak. Press the score on the result screen to see how it was worked out.':
      'Točan checkout s preostalim vremenom na satu donosi onoliko bodova koliko imaš checkouta zaredom: 1, pa 2, pa 3. Promašaj ne košta ništa, ali brojanje kreće ponovno od 0. Ako je sat istekao, točan odgovor vrijedi 0, ali čuva tvoj niz. Pritisni rezultat na ekranu s rezultatom da vidiš kako je izračunat.',
  'You start on {seconds}s and the clock counts down. Past zero it goes negative. Replay checkout has no clock and no points.':
      'Počinješ s {seconds}s i sat odbrojava. Nakon nule ide u minus. Ponovi checkout nema sat ni bodove.',
  'Undo can be used {max} times in a session. The number in brackets is how many are left. Choose the game again for {max} more. Once all of them are used, the next miss ends the session: you see your score, and Replay session starts a new one from 0.':
      'Poništi se može koristiti {max} puta u sesiji. Broj u zagradi je koliko ih je ostalo. Odaberi igru ponovno za još {max}. Kad se sva iskoriste, sljedeći promašaj završava sesiju: vidiš svoj rezultat, a Ponovi sesiju započinje novu od 0.',
};
