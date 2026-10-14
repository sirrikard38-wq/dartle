import 'better_doubles.dart';
import 'bull_safe_finish.dart';
import 'challenge.dart';
import 'checkout_route.dart';
import 'natural_aim.dart';
import 'optimal_route_service.dart';

/// Writes the "Show why." text: why a number is played the way it is, and why
/// the route the player chose is optimal or not. Pure text, built from the same
/// rules as [OptimalRouteService], one plain sentence per line.
abstract final class RouteExplainer {
  static List<String> explain({
    required Challenge challenge,
    required List<CheckoutRoute> optimalRoutes,
    CheckoutRoute? playerRoute,
    bool playerCorrect = false,
    bool playerOptimal = false,
    String? mistake,
  }) {
    final target = challenge.target;
    if (!challenge.hasCheckout) {
      return [
        '$target cannot be checked out: no three darts that end on a double or '
            'the Bull add up to $target.',
        'The best you can do is use no darts at all, which is why the right '
            'answer is "No checkout".',
      ];
    }

    final lines = <String>[];
    final fewest = challenge.dartCount;
    final primary = optimalRoutes.first;
    lines.add('$target needs at least $fewest ${_darts(fewest)}, so only a route '
        'with $fewest ${_darts(fewest)} can be optimal.');
    lines.addAll(_rule(challenge, primary));
    lines.add('Optimal routes: ${optimalRoutes.take(6).map((r) => r.notation).join(', ')}'
        '${optimalRoutes.length > 6 ? ', ...' : ''}.');
    if (optimalRoutes.any(BetterDoubles.leavesBetterDouble)) {
      lines.add('A finish on a better double (D20, D18, D16, D14, D12, D10, D8, D6, '
          'D5, D4, D2 or D1) leaves you an easier double to follow up on.');
    }

    final player = playerRoute;
    if (player != null && !player.isEmpty) {
      lines.addAll(_verdict(challenge, optimalRoutes, player, playerCorrect,
          playerOptimal, mistake));
    }
    return lines;
  }

  static String _darts(int n) => n == 1 ? 'dart' : 'darts';

  /// The rule that decided the route.
  static List<String> _rule(Challenge challenge, CheckoutRoute primary) {
    final target = challenge.target;
    final fewest = challenge.dartCount;
    final singles = OptimalRouteService.singles(primary);

    if (fewest == 1) {
      return ['One dart finishes it: ${primary.notation}.'];
    }

    if (fewest == 2 && BullSafeFinish.covers(target)) {
      final n = target - BullSafeFinish.bullScore;
      if (challenge.layout.bullSafe) {
        final treble = BullSafeFinish.twoDartFinish(target);
        return [
          'Bull-safe: with two darts left on $target, aim at $n, because the '
              'single $n leaves exactly 50, which is the Bull.',
          if (treble != null)
            'Throw the triple $n (${3 * n}) and then ${treble.darts.last.notation}, '
                'or throw S$n and then the Bull. Both are equally good.'
          else
            'There is no triple route for $target, so it is S$n and then the Bull.',
          'If you aim at the triple and hit the single instead, you still have '
              'the Bull left, so a near miss still has a finish.',
        ];
      }
      return [
        'The last box is used, so the usual rule applies: a single is far easier '
            'to hit than a double or a triple.',
        'So a single and then a double is best: $singles single in '
            '${primary.notation}.',
      ];
    }

    if (fewest == 3 && BullSafeFinish.threeDartRoutes(target).isNotEmpty) {
      final routes = BullSafeFinish.threeDartRoutes(target);
      final example = routes.first;
      final left = target - example.darts.first.score;
      final n = left - BullSafeFinish.bullScore;
      return [
        'Bull-safe: with three darts, the first dart should leave 51 to 70. '
            '${example.darts.first.notation} leaves $left.',
        if (left >= BullSafeFinish.minRemaining)
          'Then it is the triple of $n and a double, or the single $n and the Bull: '
              '${routes.take(2).map((x) => x.notation).join(' or ')}. A near miss '
              'still leaves the Bull.'
        else
          'Then it is the single $n and the Bull: ${example.notation}. A near miss '
              'still leaves the Bull.',
      ];
    }

    if (singles > 0) {
      return [
        'Singles are far easier to hit than doubles or triples. With the same '
            'number of darts, the routes with the most singles win.',
        '${primary.notation} has $singles ${singles == 1 ? 'single' : 'singles'}, '
            'so any route with $singles ${singles == 1 ? 'single' : 'singles'} '
            'and the same number of darts is equally good.',
      ];
    }
    return [
      'No single can do the job, so triples are used. T15 to T20 are the '
          'sensible ones; a low triple like T3 is not.',
      'A double as a setup dart is the hardest, so it ranks last.',
    ];
  }

  static List<String> _verdict(
    Challenge challenge,
    List<CheckoutRoute> optimalRoutes,
    CheckoutRoute player,
    bool correct,
    bool optimal,
    String? mistake,
  ) {
    final text = player.notation;
    if (!correct) {
      return ['Your darts $text do not check out. ${mistake ?? ''}'.trim()];
    }
    if (optimal) {
      return ['Your route $text is one of the optimal routes.'];
    }

    final primary = optimalRoutes.first;
    final reasons = <String>[];
    if (player.length > challenge.dartCount) {
      reasons.add('it uses ${player.length} darts, and the fewest is ${challenge.dartCount}');
    } else {
      final mine = OptimalRouteService.singles(player);
      final best = OptimalRouteService.singles(primary);
      final bullSafe = challenge.dartCount == 2 &&
          BullSafeFinish.covers(challenge.target) &&
          challenge.layout.bullSafe;
      if (bullSafe) {
        reasons.add('with the first box used it should be the triple of '
            '${challenge.target - BullSafeFinish.bullScore} or its single, then a '
            'double or the Bull (the bull-safe route)');
      } else if (mine < best) {
        reasons.add('it has $mine ${mine == 1 ? 'single' : 'singles'} where the best '
            'routes have $best, and a single is far easier to hit');
      }
      final silly = player.setupDarts.where((d) => !NaturalAim.isNatural(d)).toList();
      if (silly.isNotEmpty) {
        reasons.add('${silly.map((d) => d.notation).join(' and ')} '
            '${silly.length == 1 ? 'is' : 'are'} not a sensible aim');
      }
    }
    if (reasons.isEmpty) reasons.add('it is not one of the optimal routes');
    return ['Your route $text checks out, but it is not optimal: ${reasons.join('; ')}.'];
  }
}
