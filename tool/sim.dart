// ignore_for_file: avoid_print
// Headless balance check (spec 02 §9).
//   dart run tool/sim.dart [runs]
// Plays runs with three bots and prints clear rates, where runs die, and how
// much each figure lifts the clear rate when it was on the shelf.

import 'dart:math' as math;

import 'package:oshi_saidan/logic/defs.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';

typedef Bot = ({String name, bool smart, bool shop});

/// How often a mashing player fends off a 妨害 (before his power).
const jamDefense = 0.75;

int _score(Run r, FigureDef d, int idx) {
  final c = r.clone();
  // an occupied cell means stacking the same goods on itself
  c.cells[idx] == null ? c.place(d, idx) : c.overwrite(d, idx);
  var s = c.coins - r.coins;
  // look two turns ahead so growers and fuses are valued
  s += c.endTurn().total;
  s += c.endTurn().total ~/ 2;
  return s;
}

({bool cleared, int paydays, Set<String> used, int earned}) play(int seed, Bot bot, [Rules Function()? rules]) {
  final r = Run(seed: seed, rules: rules?.call());
  final rnd = math.Random(seed);
  final used = <String>{};

  void put(List<FigureDef> opts) {
    final empty = r.emptyCells;
    // a smart player also considers stacking a goods on its twin
    final stacks = bot.smart ? [for (final d in opts) for (var i = 0; i < r.size; i++) if (r.stacksOn(d, i)) i] : <int>[];
    if (empty.isEmpty && stacks.isEmpty) return;
    if (!bot.smart) {
      if (empty.isEmpty) return;
      r.place(opts[rnd.nextInt(opts.length)], empty[rnd.nextInt(empty.length)]);
      return;
    }
    FigureDef? bd;
    var bi = -1, bs = -1 << 30;
    for (final d in opts) {
      for (final i in [...empty, ...stacks.where((i) => r.stacksOn(d, i))]) {
        final s = _score(r, d, i);
        if (s > bs) {
          bs = s;
          bd = d;
          bi = i;
        }
      }
    }
    r.cells[bi] == null ? r.place(bd!, bi) : r.overwrite(bd!, bi);
  }

  while (true) {
    put(r.pull());
    for (final f in r.figs) {
      used.add(f.def.id);
    }
    // a 妨害: a player mashing まもれ！ fends off about half of them
    final jam = r.rollJam();
    if (jam != null) {
      if (rnd.nextDouble() >= jamDefense / jam.power) {
        r.applyJam(jam);
      } else if (r.rewardJam(jam) case final gift?) {
        put([gift]);
      }
    }
    r.endTurn();
    if (!r.paydayNow) continue;
    final p = r.payday();
    if (!p.paid) return (cleared: false, paydays: r.paydaysPaid, used: used, earned: r.earned);
    if (r.cleared) return (cleared: true, paydays: r.paydaysPaid, used: used, earned: r.earned);
    if (bot.shop) {
      r.rollShop();
      final reserve = r.baseDue(r.paydaysPaid) ~/ 4;
      for (final o in [...r.shop]..sort((a, b) => b.price - a.price)) {
        // the bot never re-pulls, so that upgrade would be wasted coins
        if (o.kind == OfferKind.repullTicket) continue;
        if (r.coins - r.priceOf(o) < reserve) continue;
        final d = r.buy(o);
        if (d != null) put([d]);
      }
    }
  }
}

double rate(int n, Bot bot, Rules Function() rules) {
  var w = 0;
  for (var s = 1; s <= n; s++) {
    if (play(s * 7919, bot, rules).cleared) w++;
  }
  return w / n;
}

String pct(double x) => '${(x * 100).toStringAsFixed(0).padLeft(3)}%';

void main(List<String> args) {
  final n = args.isEmpty ? 2000 : int.parse(args.first);
  const bots = <Bot>[
    (name: 'random', smart: false, shop: false),
    (name: 'greedy', smart: true, shop: false),
    (name: 'greedy+shop', smart: true, shop: true),
  ];
  final m = n ~/ 2;
  // each machine at the level it unlocks (what a player meets first), and with everything out
  print('── machines at their unlock level / at Lv15: random / greedy / greedy+shop');
  for (final mc in machines) {
    final lv = mc.unlock == UnlockKind.level ? mc.unlockN : 1;
    print('   ${mc.name.padRight(14)} Lv${'$lv'.padRight(2)} ${[for (final b in bots) pct(rate(m, b, () => rulesFor(mc)..level = lv))].join(' ')}   '
        'Lv15 ${[for (final b in bots) pct(rate(m, b, () => rulesFor(mc)..level = 15))].join(' ')}');
  }
  print('── 推し活レベル on ぷりパレガチャ: random / greedy+shop');
  print('   ${[for (final l in [1, 3, 5, 7, 9, 11, 13, 15]) 'Lv$l ${pct(rate(m, bots[0], () => rulesFor(machines.first)..level = l))}/${pct(rate(m, bots[2], () => rulesFor(machines.first)..level = l))}'].join('  ')}');
  for (final bot in bots) {
    var wins = 0;
    final died = List.filled(Run.clearPaydays + 1, 0);
    final withF = <String, int>{}, winsWithF = <String, int>{};
    for (var s = 1; s <= n; s++) {
      final res = play(s * 7919, bot, () => rulesFor(machines.first)..level = 1);
      if (res.cleared) wins++;
      died[res.paydays]++;
      for (final id in res.used) {
        withF[id] = (withF[id] ?? 0) + 1;
        if (res.cleared) winsWithF[id] = (winsWithF[id] ?? 0) + 1;
      }
    }
    final rate = wins / n;
    print('── ${bot.name}: clear ${(rate * 100).toStringAsFixed(1)}%');
    print('   paydays reached: ${[for (var i = 0; i < died.length; i++) '$i:${died[i]}'].join('  ')}');
    if (bot.smart) {
      final lifts = [
        for (final f in figures)
          if ((withF[f.id] ?? 0) >= 30)
            (f.name, (winsWithF[f.id] ?? 0) / withF[f.id]! - rate, withF[f.id]!)
      ]..sort((a, b) => b.$2.compareTo(a.$2));
      print('   lift: ${lifts.map((l) => '${l.$1} ${(l.$2 * 100).toStringAsFixed(0)}').join(' / ')}');
    }
  }
}
