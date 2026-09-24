import 'package:flutter/material.dart';

import '../engine/game_symbol.dart';
import 'app_theme.dart';

/// How a symbol is drawn.
///
/// Fruit and gems carry enough colour as glyphs; the classic slot symbols —
/// BAR, the seven, WILD — are set as type, the way a real cabinet does it.
/// Swapping in artwork later means changing this one file: give the class an
/// asset path and have [SymbolArt] render an `Image.asset`.
class SymbolStyle {
  const SymbolStyle({
    required this.glyph,
    required this.tint,
    this.asText = false,
    this.letterSpacing = 0,
  });

  final String glyph;

  /// Drives the cell's glow and the win highlight.
  final Color tint;

  /// Set the glyph as type rather than as a picture glyph.
  final bool asText;

  final double letterSpacing;

  static const Map<GameSymbol, SymbolStyle> _styles = <GameSymbol, SymbolStyle>{
    GameSymbol.cherry: SymbolStyle(glyph: '🍒', tint: AppTheme.crimson),
    GameSymbol.lemon: SymbolStyle(glyph: '🍋', tint: Color(0xFFF5D547)),
    GameSymbol.grape: SymbolStyle(glyph: '🍇', tint: Color(0xFFA974FF)),
    GameSymbol.bell: SymbolStyle(glyph: '🔔', tint: Color(0xFFFFB454)),
    GameSymbol.bar: SymbolStyle(
      glyph: 'BAR',
      tint: AppTheme.ice,
      asText: true,
      letterSpacing: 1,
    ),
    GameSymbol.diamond: SymbolStyle(glyph: '💎', tint: AppTheme.ice),
    GameSymbol.seven: SymbolStyle(
      glyph: '7',
      tint: AppTheme.crimson,
      asText: true,
    ),
    GameSymbol.wild: SymbolStyle(
      glyph: 'WILD',
      tint: AppTheme.gold,
      asText: true,
      letterSpacing: 0.5,
    ),
    GameSymbol.scatter: SymbolStyle(glyph: '⭐', tint: AppTheme.mint),
  };

  static SymbolStyle of(GameSymbol symbol) => _styles[symbol]!;
}

/// Draws one symbol, sized to fill its cell.
class SymbolArt extends StatelessWidget {
  const SymbolArt({
    required this.symbol,
    required this.size,
    this.highlighted = false,
    super.key,
  });

  final GameSymbol symbol;

  /// The cell's short side; the glyph is sized from it.
  final double size;

  /// Winning symbols brighten and gain a halo.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final SymbolStyle style = SymbolStyle.of(symbol);

    if (style.asText) {
      // Type-set symbols read best filling the cell width.
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.1),
            child: Text(
              style.glyph,
              maxLines: 1,
              style: TextStyle(
                fontSize: size * (symbol == GameSymbol.seven ? 0.72 : 0.34),
                fontWeight: FontWeight.w900,
                letterSpacing: style.letterSpacing,
                height: 1,
                foreground: Paint()
                  ..shader = AppTheme.goldSheen.createShader(
                    Rect.fromLTWH(0, 0, size, size),
                  ),
                shadows: <Shadow>[
                  Shadow(
                    color: style.tint.withValues(
                      alpha: highlighted ? 0.95 : 0.55,
                    ),
                    blurRadius: highlighted ? 22 : 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        style.glyph,
        style: TextStyle(
          fontSize: size * 0.52,
          height: 1,
          shadows: <Shadow>[
            Shadow(
              color: style.tint.withValues(alpha: highlighted ? 0.9 : 0.45),
              blurRadius: highlighted ? 26 : 12,
            ),
          ],
        ),
      ),
    );
  }
}
