import 'game_symbol.dart';

/// The physical reel bands.
///
/// A slot machine does not roll a fresh random symbol into every cell. Each
/// reel is a fixed loop of symbols and a spin only chooses *where the loop
/// stops*; three consecutive band positions then form the visible column. That
/// is why symbols sitting near each other on a band tend to show up together,
/// and it is what makes the return-to-player exactly computable — see
/// `tool/exact_rtp.dart`.
///
/// Every band here holds the same 30-symbol recipe:
///
/// | Symbol    | Per band | In a 3-row window |
/// |-----------|----------|-------------------|
/// | Cherry    | 6        | 20.0%             |
/// | Lemon     | 5        | 16.7%             |
/// | Grape     | 5        | 16.7%             |
/// | Bell      | 4        | 13.3%             |
/// | BAR       | 3        | 10.0%             |
/// | Diamond   | 3        | 10.0%             |
/// | Wild      | 2        |  6.7%             |
/// | Seven     | 1        |  3.3%             |
/// | Scatter   | 1        |  3.3%             |
///
/// Symbol frequency is the primary RTP dial, and it outranks the paytable: a
/// symbol's rank in [Paytable.linePays] only makes sense if the band makes it
/// correspondingly rare. Keeping the recipe identical across bands means the
/// ranking holds on every reel. Giving individual reels their own recipe — a
/// friendlier reel 1, no wild on reel 5 — is the next tuning lever, and the
/// exact calculator will price it for you.
///
/// Within a band the order matters too, even though it does not change the RTP
/// by itself: spacing the wilds and keeping one scatter per band stops the
/// window from showing awkward clumps.
class ReelStrips {
  const ReelStrips._();

  // Short aliases keep each band readable as a single block.
  static const GameSymbol _c = GameSymbol.cherry;
  static const GameSymbol _l = GameSymbol.lemon;
  static const GameSymbol _g = GameSymbol.grape;
  static const GameSymbol _b = GameSymbol.bell;
  static const GameSymbol _br = GameSymbol.bar;
  static const GameSymbol _d = GameSymbol.diamond;
  static const GameSymbol _s7 = GameSymbol.seven;
  static const GameSymbol _w = GameSymbol.wild;
  static const GameSymbol _sc = GameSymbol.scatter;

  static const List<GameSymbol> _reel1 = <GameSymbol>[
    _c, _l, _b, _g, _c, _d, _l, _br, _c, _w, //
    _g, _l, _b, _c, _d, _g, _sc, _l, _br, _c, //
    _b, _g, _s7, _l, _c, _d, _b, _g, _br, _w, //
  ];

  static const List<GameSymbol> _reel2 = <GameSymbol>[
    _l, _c, _g, _b, _d, _c, _br, _l, _w, _g, //
    _c, _s7, _b, _l, _g, _br, _c, _sc, _l, _b, //
    _d, _g, _c, _br, _l, _b, _g, _d, _c, _w, //
  ];

  static const List<GameSymbol> _reel3 = <GameSymbol>[
    _g, _c, _l, _br, _b, _w, _c, _g, _d, _l, //
    _b, _c, _s7, _g, _br, _l, _c, _sc, _b, _g, //
    _l, _d, _c, _br, _g, _b, _l, _c, _d, _w, //
  ];

  static const List<GameSymbol> _reel4 = <GameSymbol>[
    _b, _l, _c, _g, _br, _l, _w, _c, _b, _d, //
    _g, _l, _c, _s7, _br, _b, _g, _sc, _l, _c, //
    _d, _b, _g, _br, _l, _c, _d, _g, _c, _w, //
  ];

  static const List<GameSymbol> _reel5 = <GameSymbol>[
    _c, _g, _b, _l, _d, _c, _br, _g, _w, _b, //
    _c, _l, _s7, _g, _b, _br, _c, _sc, _l, _g, //
    _d, _c, _b, _br, _g, _l, _c, _d, _l, _w, //
  ];

  /// One band per reel, left to right.
  static const List<List<GameSymbol>> standard = <List<GameSymbol>>[
    _reel1,
    _reel2,
    _reel3,
    _reel4,
    _reel5,
  ];
}
