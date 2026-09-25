# Lucky Five — an Android slot machine in Dart

A five-reel, ten-payline slot machine built with Flutter. The game maths is
plain Dart with no Flutter imports, so it can be unit tested and simulated from
the command line; the Flutter layer only draws it.

**Play money only.** There is no real-money wagering and nothing to buy.

---

## How to start, if you are doing this yourself

This is the order that matters, and it is worth resisting the urge to start
with the pretty spinning reels.

### 1. Pick the shape of the machine before writing any code

Decide the grid, the paylines and the symbol set first, because everything else
is downstream of them. This one is 5 reels x 3 rows, 10 fixed paylines, 9
symbols including a wild and a scatter. A 3x3 with a single payline is a
perfectly good first target and much less arithmetic.

### 2. Model reels the way real machines do

The tempting implementation is to roll a random symbol into each of the 15
cells. Don't: it makes the odds almost impossible to reason about, and it
produces grids that feel wrong, because real reels are *fixed loops of symbols*
and a spin only chooses **where each loop stops**.

That single decision buys you a lot:

- symbol frequency becomes an explicit, readable table (`reel_strips.dart`)
- near-misses happen naturally, because a stop one position off shows the
  symbol next to the one you wanted
- the return to player becomes exactly computable rather than something you
  have to sample

### 3. Write the maths as pure Dart, with the UI nowhere near it

`lib/src/engine/` imports nothing from Flutter. A spin is two steps: choose a
stop per reel, then score the window those stops expose. It never looks at the
player's balance. That separation is what lets `tool/rtp.dart` play two million
spins in a couple of seconds, and what lets tests hand-place a jackpot instead
of spinning until one turns up.

### 4. Measure the return to player, then tune it — do not guess it

This is the step most hobby slot games skip, and it is the one that decides
whether the game is any fun. The first draft of this paytable returned **40.8%**
of stake. That is unplayably stingy; commercial machines ship between roughly
88% and 97%. Nothing in the code was wrong, and no amount of playing it would
have told you the number.

So measure it:

```bash
dart run tool/exact_rtp.dart     # exact, closed form, instant
dart run tool/rtp.dart 2000000   # independent check by simulation
```

Then move the reel bands and the payouts until the number is where you want it.
This game landed at **94.51%**, with a 43% hit frequency. The two tools agree to
within sampling error, which is the point of having both: if they ever disagree,
one of them is scoring spins wrongly.

### 5. Only now build the reels you can see

The controller decides the outcome the instant the button is pressed, and the
animation travels to a result that already exists. That is how a real cabinet
works, and it means no amount of fiddling with the UI can change the odds.

### 6. Make it feel like a machine

Mostly small things, and mostly timing: reels stopping left to right, motion
blur that tracks actual reel speed, the band overshooting its stop and easing
back, credits rolling up instead of jumping, winning lines drawn one at a time,
haptics on the button and on a win.

---

## Why the RTP can be computed exactly

Worth understanding, because it is the difference between guessing and knowing,
and it takes one paragraph.

A payline takes one row from each reel. As a band's stop position runs over all
30 of its positions, the symbol landing on that row runs over the whole band
exactly once. So the symbol on a payline follows that band's symbol
frequencies, independently per reel — and **every payline has the same
expectation**, whatever shape it traces. The sum over all 24,300,000 stop
combinations therefore collapses to a weighted sum over 9^5 = 59,049 symbol
combinations, which is instant.

Scatters pay off the whole grid rather than a line, but the number of scatters
in one reel's window depends only on that reel's stop, so the totals are the
convolution of five small per-reel distributions.

`lib/src/engine/rtp.dart` does both, scoring lines with `SlotMachine.scoreLine`
— the same code that pays the player — so the published figure cannot drift away
from the real game. The paytable screen in the app reads its RTP from it rather
than from a hardcoded string.

---

## The maths as it currently stands

| | |
|---|---|
| Grid | 5 reels x 3 rows, 30-symbol bands |
| Paylines | 10, fixed, paying left to right |
| Base game RTP | 82.08% |
| Effective RTP | **94.51%** including free spins |
| House edge | 5.49% |
| Hit frequency | ~43% of spins pay something |
| Free spins | 1 in ~119 spins, 8–20 spins at 2x, retriggerable |
| Top line win | 4,000x the line bet (400x total bet) for five wilds |

Symbol frequency per band, which is the main dial:

| Symbol | Per band | Line pay 3 / 4 / 5 |
|---|---|---|
| Wild | 2 | 150 / 750 / 4000 |
| Seven | 1 | 60 / 250 / 1500 |
| Diamond | 3 | 15 / 50 / 200 |
| BAR | 3 | 12 / 40 / 125 |
| Bell | 4 | 8 / 25 / 100 |
| Grape | 5 | 5 / 15 / 40 |
| Lemon | 5 | 5 / 15 / 40 |
| Cherry | 6 | 3 / 10 / 25 |
| Scatter | 1 | pays 6 / 30 / 250 x **total** bet, anywhere |

The pay ranking follows the band frequencies, which is what makes it coherent:
wilds top the table because five wilds is rarer than five sevens — wilds can
complete a seven run, but nothing completes a wild run.

---

## Running it

Needs the Flutter SDK and, for a device build, the Android SDK.

```bash
flutter pub get
flutter test                  # 77 tests
flutter run                   # on a connected device or emulator
flutter build apk --release   # installable APK
```

Tuning tools, neither of which needs a device:

```bash
dart run tool/exact_rtp.dart      # exact RTP and where it comes from
dart run tool/rtp.dart 5000000    # simulate, and check the exact figure
```

---

## Layout

```
lib/
  main.dart                    App entry, portrait lock, wiring
  src/
    engine/                    Pure Dart. No Flutter imports.
      game_symbol.dart         The symbol set
      paytable.dart            Grid, paylines, payouts — the tuning dials
      reel_strips.dart         The reel bands, and the frequency recipe
      slot_machine.dart        Spin and scoring: wilds, scatters, paylines
      spin_result.dart         What a spin produced
      rtp.dart                 Exact return-to-player calculation
    game/
      game_controller.dart     Balance, stake, spin lifecycle, free spins
      wallet.dart              Persistence, with an in-memory double
      spin_timing.dart         Shared animation schedule
    ui/
      slot_screen.dart         The cabinet
      reel_view.dart           One spinning reel
      payline_overlay.dart     Winning lines, drawn and cycled
      symbol_art.dart          Symbol rendering — swap in artwork here
      controls_bar.dart        Spin, bet ladder, autoplay, turbo
      paytable_sheet.dart      In-game paytable and rules
      readouts.dart            Rolling credit counters
      win_banner.dart          Win tiers and celebration
      app_theme.dart           Colours and text styles
test/
  engine/                      Scoring rules, and RTP regression
  game/                        Controller, using fake timers
  ui/                          Widget tests for the screen
  support/                     Machines with known outcomes
tool/
  exact_rtp.dart               Closed-form RTP
  rtp.dart                     Monte Carlo cross-check
```

## Where to change things

| To change | Edit |
|---|---|
| Payouts, paylines, bet ladder | `engine/paytable.dart` |
| How often a symbol lands | `engine/reel_strips.dart` |
| Add a symbol | `engine/game_symbol.dart`, then both of the above |
| Reel speed and stagger | `game/spin_timing.dart` |
| Symbol artwork | `ui/symbol_art.dart` |
| Colours | `ui/app_theme.dart` |

After touching either of the first two, run `dart run tool/exact_rtp.dart` and
`flutter test` — `test/engine/rtp_test.dart` deliberately fails if the return to
player leaves its band, so an accidental economy change cannot slip through.

## Worth adding next

- **Sound.** The largest single gap. Reel stops, win stings and a bonus fanfare
  do more for feel than any visual effect. Add `audioplayers`, put clips in
  `assets/audio/`, and trigger them where the haptics already fire.
- **Artwork.** `symbol_art.dart` is the only file that needs to change.
- **A server-side RNG**, if this ever became more than play money. The engine
  takes an injectable `Random`, so the seam is already there — and real-money
  gambling is licensed and regulated, which is a legal question long before it
  is a technical one.
