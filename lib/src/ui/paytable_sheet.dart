import 'package:flutter/material.dart';

import '../engine/game_symbol.dart';
import '../engine/paytable.dart';
import '../engine/rtp.dart';
import 'app_theme.dart';
import 'symbol_art.dart';

/// The in-game paytable, rules and published return to player.
///
/// The RTP shown here is not a hardcoded marketing number — it is computed from
/// the live paytable and reel bands by [computeExactRtp], so it cannot fall out
/// of step with what the machine actually pays.
class PaytableSheet extends StatelessWidget {
  const PaytableSheet({required this.betPerLine, super.key});

  /// Payouts are shown at the player's current stake, which is far easier to
  /// read than a table of multipliers.
  final int betPerLine;

  static Future<void> show(BuildContext context, {required int betPerLine}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cabinet,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxHeight: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => PaytableSheet(betPerLine: betPerLine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RtpReport report = computeExactRtp();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: <Widget>[
        Text('PAYTABLE', style: AppTheme.label.copyWith(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          'Wins pay left to right on ${Paytable.lineCount} lines '
          'at $betPerLine per line.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 16),
        const _TableHeader(),
        const Divider(height: 14, color: AppTheme.cabinetEdge),
        for (final GameSymbol symbol in Paytable.payingSymbolsByValue)
          _PayRow(symbol: symbol, betPerLine: betPerLine),
        const Divider(height: 22, color: AppTheme.cabinetEdge),
        _ScatterRow(betPerLine: betPerLine),
        const SizedBox(height: 22),
        _RuleBlock(
          title: 'Wild',
          body:
              'Stands in for every symbol except the scatter, and pays the '
              'top prize in its own right.',
        ),
        _RuleBlock(
          title: 'Scatter',
          body:
              'Pays anywhere on the reels, not just on a line. '
              '${Paytable.minMatch} or more also award free spins, where every '
              'win is multiplied by ${Paytable.freeSpinMultiplier}. Landing '
              'more scatters during the bonus extends it.',
        ),
        _RuleBlock(
          title: 'Return to player',
          body:
              '${(report.effectiveRtp * 100).toStringAsFixed(2)}% over the '
              'long run, of which '
              '${(report.baseRtp * 100).toStringAsFixed(2)}% comes from the '
              'base game. Any one line pays on '
              '${(report.lineHitRate * 100).toStringAsFixed(2)}% of spins.',
        ),
        const SizedBox(height: 8),
        Text(
          'Play money only. No real-money wagering, no purchases.',
          style: AppTheme.label.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 44),
        const Spacer(),
        for (
          int count = Paytable.minMatch;
          count <= Paytable.reelCount;
          count++
        )
          SizedBox(
            width: 62,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: AppTheme.label,
            ),
          ),
      ],
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.symbol, required this.betPerLine});

  final GameSymbol symbol;
  final int betPerLine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            height: 40,
            child: SymbolArt(symbol: symbol, size: 40),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              symbol.displayName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
          for (
            int count = Paytable.minMatch;
            count <= Paytable.reelCount;
            count++
          )
            SizedBox(
              width: 62,
              child: Text(
                '${Paytable.linePay(symbol, count) * betPerLine}',
                textAlign: TextAlign.right,
                style: AppTheme.counter.copyWith(
                  fontSize: 13,
                  color: count == Paytable.reelCount
                      ? SymbolStyle.of(symbol).tint
                      : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScatterRow extends StatelessWidget {
  const _ScatterRow({required this.betPerLine});

  final int betPerLine;

  @override
  Widget build(BuildContext context) {
    final int totalBet = betPerLine * Paytable.lineCount;
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 40,
          height: 40,
          child: SymbolArt(symbol: GameSymbol.scatter, size: 40),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Scatter\npays total bet',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
          ),
        ),
        for (
          int count = Paytable.minMatch;
          count <= Paytable.reelCount;
          count++
        )
          SizedBox(
            width: 62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${Paytable.scatterPay(count) * totalBet}',
                  style: AppTheme.counter.copyWith(
                    fontSize: 13,
                    color: AppTheme.mint,
                  ),
                ),
                Text(
                  '+${Paytable.freeSpinsFor(count)} FS',
                  style: AppTheme.label.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: AppTheme.label.copyWith(color: AppTheme.gold),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
