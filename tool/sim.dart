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

int _score(Run r, FigureDef d, int idx) {
  final c = r.clone();
  c.place(d, idx);
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
    if (empty.isEmpty) return;
    if (!bot.smart) {
      r.place(opts[rnd.nextInt(opts.length)], empty[rnd.nextInt(empty.length)]);
      return;
    }
    FigureDef? bd;
    var bi = -1, bs = -1 << 30;
    for (final d in opts) {
      for (final i in empty) {
        final s = _score(r, d, i);
        if (s > bs) {
          bs = s;
          bd = d;
          bi = i;
        }
      }
    }
    r.place(bd!, bi);
  }

  while (true) {
    put(r.pull());
    for (final f in r.figs) {
      used.add(f.def.id);
    }
    // smart bots throw away the boss's card when they can
    if (bot.smart && r.removeTickets > 0) {
      final card = r.cells.indexWhere((f) => f?.def.id == kCardId);
      if (card >= 0) r.remove(card);
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
        // the bot never swaps or re-pulls, so those upgrades would be wasted coins
        if (o.kind == OfferKind.swapTicket || o.kind == OfferKind.repullTicket) continue;
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
  final m = n ~/ 4;
  print('── machines (asc 0): random / greedy / greedy+shop');
  for (final mc in machines) {
    print('   ${mc.name.padRight(10)} ${[for (final b in bots) pct(rate(m, b, () => rulesFor(mc, 0)))].join(' ')}');
  }
  print('── 推し活レベル on ぷりパレガチャ (greedy+shop): which figures can drop');
  print('   ${[for (final l in [1, 3, 5, 7, 9, 11, 13, 15]) 'Lv$l ${pct(rate(m, bots[2], () => rulesFor(machines.first, 0)..level = l))}'].join('  ')}');
  print('── ascension on ぷりパレガチャ (greedy+shop)');
  print('   ${[for (var a = 0; a <= maxAscension; a += 2) 'A$a ${pct(rate(m, bots[2], () => rulesFor(machines.first, a)))}'].join('  ')}');
  for (final bot in bots) {
    var wins = 0;
    final died = List.filled(Run.clearPaydays + 1, 0);
    final withF = <String, int>{}, winsWithF = <String, int>{};
    for (var s = 1; s <= n; s++) {
      final res = play(s * 7919, bot);
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
