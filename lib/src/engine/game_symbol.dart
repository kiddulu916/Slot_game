/// Every symbol that can land on the reels.
///
/// The engine is deliberately free of Flutter imports so the maths can be
/// unit tested and simulated from a plain `dart run` script.
enum GameSymbol {
  cherry('Cherry'),
  lemon('Lemon'),
  grape('Grape'),
  bell('Bell'),
  horseshoe('Horseshoe'),
  diamond('Diamond'),
  seven('Lucky Seven'),
  wild('Wild'),
  scatter('Scatter');

  const GameSymbol(this.displayName);

  final String displayName;

  /// Wilds substitute for every symbol except [scatter].
  bool get isWild => this == GameSymbol.wild;

  /// Scatters pay anywhere on the grid and never take part in line wins.
  bool get isScatter => this == GameSymbol.scatter;
}
