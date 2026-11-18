# Pikado izlazi (checkout) – kontekst za tutorijal u Dartleu

Ovaj dokument sažima raspravu iz drugog chata. Uz njega su tri CSV tablice (izlazi-3-strelice.csv, izlazi-2-strelice.csv, izlazi-1-strelica.csv) koje su glavni izvor podataka.

## Cilj

Dodati u Dartle dio za učenje i vježbu izlaza (zadnja strelica mora biti double ili BULL, brojevi 2–170). Za zadani broj i broj strelica u ruci (3, 2 ili 1) aplikacija kaže što gađati, zašto to, a zašto ne nešto drugo. Ton: direktan, bez preobjašnjavanja.

## Glavna ideja ("ključno polje")

Ne gleda se samo što ostaje nakon pogotka, nego što ostaje nakon promašaja susjednog polja. Primjer 127 s 3 strelice:

```
127 – gađaj T20
  pogodak T20  -> 67   -> T17 + D8      izlaz moguć
  promašaj S20 -> 107  -> T19 + BULL    izlaz još moguć

127 – ne T19
  pogodak T19  -> 70   -> T10 + D20     izlaz moguć
  promašaj S19 -> 108                   nemoguće u 2 strelice
```

## Pravila logike (iz korisnikove liste)

- Izlaz = zadnja strelica u double ili BULL.
- Gleda se što ostaje nakon promašaja susjednog broja.
- Doubli se preferiraju tako da se mogu "prepoloviti": D16 -> D8 -> D4 -> D2 -> D1.
- Singlovi su najlakši. Dva susjedna singla koja ostavljaju double su dobar izbor.
- Triple i single istog broja često su oba u redu.
- 61–70 s 2 strelice: triple.
- 127: T20, ne T19.
- 167 = T20, T19, BULL (jedini način). 170 = T20, T20, BULL (Big Fish).
- Nema izlaza u 3 strelice: 159, 162, 163, 165, 166, 168, 169.

## Kako su tablice izračunate

- Geometrijski model ploče (stvarni radijusi i redoslijed polja) s Gaussovim rasipanjem ciljanja. Razine: sigma 10 mm i 14 mm (jači do prosječnog klupskog igrača).
- Dinamičko programiranje: za svaki broj i broj strelica računa se vjerojatnost izlaza u ovom posjetu i vrijednost ostatka (ako ne uspije, što ostaje). Provjera simulacijom se poklapa (npr. 62 s T14: 23,17 % simulacija, 23,00 % model).
- Glavna preporuka = praktično najbolja prema modelu; kad je razlika zanemariva, prednost ima korisnikova varijanta, zatim varijante iz izvora (dartbase, cyberdarts, Thornton, Berman, brainscape).
- Neovisna provjera svih 507 redova: 0 problema.

## Stupci u tablicama

| Stupac | Značenje |
| --- | --- |
| Broj | preostali bodovi |
| Gađaj | prva meta |
| Ruta | cijela ruta ako svaka strelica pogodi |
| Pogodak ostavlja | što ostaje nakon pogotka (IZLAZ ako je gotovo) |
| Promašaj ostavlja | što ostaje nakon najčešćeg promašaja (susjedni single) |
| Izlaz i dalje moguć | DA/NE: ima li nakon promašaja još izlaza s preostalim strelicama |
| Pravilo | vrsta odluke (vidi dolje) |
| Alternativa | do dvije gotovo jednako dobre mete (samo 3 i 2 strelice) |

Pravila (oznake): Double odmah, Single -> double, Susjedni singlovi, I single ostavlja izlaz, Triple nužan, Triple -> double / single -> BULL, BULL prvi, BULL, Priprema (izlaz nije moguć s preostalim strelicama, gađa se dobar ostatak), Nema izlaza.

## Gdje se model razlikuje od korisnikove liste

- 17 i 29: model preporučuje S9 i S13 (korisnik navodi druge varijante).
- Slični slučajevi: 61, 62, 63 i 90 (ovdje odlučuje broj "sretnih" pogodaka).
- Zbroj ne odgovara broju u korisnikovoj listi (za provjeru): 9, 19, 21, 25, 27, 31, 35, 42, 44 i 59. Brojeva 37 i 38 nema u listi.

## Plan tutorijala (dogovoreno: učenje + vježba)

**Učenje:** odabereš broj i strelice, dobiješ karticu s tri dijela.
1. Gađaj X (+ ruta).
2. Zašto: što ostaje nakon pogotka i nakon promašaja (izlaz moguć ili ne).
3. Zašto ne Y: isto za najprivlačniju alternativu, s oznakom moguće/nemoguće.

Tekst: 2–3 kratke rečenice, bez dugih objašnjenja.

**Vježba:** aplikacija zada broj i broj strelica, igrač odabere metu, aplikacija kaže je li točno i zašto (ista kartica).

**Izvor podataka:** CSV tablice. Kartica "zašto ne Y" generira se iz modela (alternativa s najmanjim gubitkom, uz što ostaje nakon njezinog promašaja).

## Otvoreno

- Tehnologija Dartlea (Python/Flutter/web) i izgled: potrebno vidjeti kod.
- Je li tutorijal besplatan ili premium dio aplikacije.
