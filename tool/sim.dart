// ignore_for_file: avoid_print
// Headless balance check (spec 02 §9).
//   dart run tool/sim.dart [runs] [machines]
// Plays runs with three bots and prints clear rates, where runs die, and how
// much each figure lifts the clear rate when it was on the shelf.

import 'dart:math' as math;

import 'package:oshi_saidan/logic/defs.dart';
import 'package:oshi_saidan/logic/figures.dart';
import 'package:oshi_saidan/logic/modes.dart';
import 'package:oshi_saidan/logic/run.dart';

typedef Bot = ({String name, bool smart, bool shop, bool expert});

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

/// The expert's look at a placing: three turns ahead (deck payoffs and fuses pay later), and a pull
/// towards one member's goods (the machine's own member, or whoever leads the altar).
int _expertScore(Run r, FigureDef d, int idx, String? focus) {
  final c = r.clone();
  c.cells[idx] == null ? c.place(d, idx) : c.overwrite(d, idx);
  var s = (c.coins - r.coins).toDouble();
  s += c.endTurn().total;
  s += c.endTurn().total * 0.75;
  s += c.endTurn().total * 0.5;
  if (focus != null && d.tags.contains(focus)) s += 4 + r.paydaysPaid * 4;
  return s.round();
}

/// Whose deck the expert builds: the machine's member, else the member with the most goods on the altar.
String? _focus(Run r) {
  final w = r.rules.tagWeight.entries.where((e) => _members.contains(e.key)).toList()..sort((a, b) => b.value.compareTo(a.value));
  if (w.isNotEmpty) return w.first.key;
  final count = <String, int>{};
  for (final f in r.figs) {
    for (final t in f.def.tags.where(_members.contains)) {
      count[t] = (count[t] ?? 0) + 1;
    }
  }
  if (count.isEmpty) return null;
  return (count.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

const _members = ['ひなた', 'しずく', 'こはる', 'よる', 'もも'];

({bool cleared, int paydays, Set<String> used, int earned}) play(int seed, Bot bot, [Rules Function()? rules, void Function(int song, int earned, int due)? onSong]) {
  final r = Run(seed: seed, rules: rules?.call());
  final rnd = math.Random(seed);
  final used = <String>{};
  var songStart = 0;

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
    final focus = bot.expert ? _focus(r) : null;
    for (final d in opts) {
      for (final i in [...empty, ...stacks.where((i) => r.stacksOn(d, i))]) {
        final s = bot.expert ? _expertScore(r, d, i, focus) : _score(r, d, i);
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
    var opts = r.pull();
    // the expert puts back a plain capsule that does nothing for the deck and pulls again
    if (bot.expert && r.repulls > 0) {
      final focus = _focus(r);
      final best = opts.map((d) => d.rarity.index).reduce(math.max);
      if (best == 0 && !opts.any((d) => focus != null && d.tags.contains(focus))) {
        r.repulls--;
        opts = r.pullAtLeast(Rarity.values[best]);
      }
    }
    put(opts);
    for (final f in r.figs) {
      used.add(f.def.id);
    }
    // a 妨害: a player mashing まもれ！ fends off about half of them
    final jam = r.rollJam();
    if (jam != null) {
      if (rnd.nextDouble() >= (bot.expert ? 0.9 : jamDefense) / jam.power) {
        r.applyJam(jam);
      } else if (r.rewardJam(jam) case final gift?) {
        put([gift]);
      }
    }
    r.endTurn();
    if (!r.paydayNow) continue;
    onSong?.call(r.paydaysPaid, r.earned - songStart, r.due);
    final p = r.payday();
    songStart = r.earned;
    if (!p.paid) return (cleared: false, paydays: r.paydaysPaid, used: used, earned: r.earned);
    if (r.cleared) return (cleared: true, paydays: r.paydaysPaid, used: used, earned: r.earned);
    if (bot.expert) {
      r.rollShop();
      _expertShop(r, put);
    } else if (bot.shop) {
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

/// The expert at the stall: buys what helps the deck (its member's boost, the extra spin, the
/// member-only song, goods that score well), uses 品がえ when nothing does, keeps a little in reserve.
void _expertShop(Run r, void Function(List<FigureDef>) put) {
  final reserve = r.baseDue(r.paydaysPaid) ~/ 5;
  for (var round = 0; round < 3; round++) {
    final focus = _focus(r);
    int worth(Offer o) => switch (o.kind) {
      OfferKind.figure => o.fig!.rarity.index * 10 + (focus != null && o.fig!.tags.contains(focus) ? 15 : 0),
      OfferKind.boost => o.idol == focus ? 30 : 0,
      OfferKind.extraSpin => 50,
      OfferKind.idolSong => o.idol == focus ? 35 : 0,
      OfferKind.rareSong => 25,
      OfferKind.expand => r.emptyCells.length <= 2 ? 40 : 10,
      OfferKind.luck => 12,
      OfferKind.rerollTicket => 5,
      OfferKind.repullTicket => 20,
    };
    var bought = false;
    for (final o in [...r.shop]..sort((a, b) => worth(b) - worth(a))) {
      if (o.sold || worth(o) < 15) continue;
      if (r.coins - r.priceOf(o) < reserve) continue;
      final d = r.buy(o);
      bought = true;
      if (d != null) put([d]);
    }
    if (bought || !r.reroll()) return;
  }
}

/// The goods in the gacha when [mc] opens: the start pool, plus what every machine listed before it
/// brings in (the list runs in the order machines tend to open).
Set<String> _openWhen(MachineDef mc) {
  final before = machines.takeWhile((x) => x.id != mc.id).map((x) => x.id).toSet();
  return {for (final f in figures) if (f.from == null || before.contains(f.from)) f.id};
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
    (name: 'random', smart: false, shop: false, expert: false),
    (name: 'greedy', smart: true, shop: false, expert: false),
    (name: 'greedy+shop', smart: true, shop: true, expert: false),
    (name: 'expert', smart: true, shop: true, expert: true),
  ];
  final m = n ~/ 2;
  // each machine with the goods a player has when it opens (the start pool plus what the machines
  // before it in the list bring in when cleared), and with every goods in the gacha
  print('── machines when they open / with every goods: random / greedy / greedy+shop / expert');
  for (final mc in machines) {
    final open = _openWhen(mc);
    print('   ${mc.name.padRight(14)} ${'${open.length}種'.padLeft(5)} ${[for (final b in bots) pct(rate(m, b, () => rulesFor(mc)..open = open))].join(' ')}   '
        'all ${[for (final b in bots) pct(rate(m, b, () => rulesFor(mc)))].join(' ')}');
  }
  if (args.contains('machines')) return; // dart run tool/sim.dart 400 machines: just the table above
  if (args.contains('growth')) {
    // dart run tool/sim.dart 400 growth: per song, what the expert earns in it against the quota (ぷりパレガチャ)
    final earned = List.generate(6, (_) => <int>[]), dues = List.generate(6, (_) => <int>[]);
    for (var s = 1; s <= n; s++) {
      play(s * 7919, bots[3], () => rulesFor(machines.first)..open = _openWhen(machines.first), (song, e, d) {
        if (song < 6) {
          earned[song].add(e);
          dues[song].add(d);
        }
      });
    }
    int med(List<int> xs) => xs.isEmpty ? 0 : (List.of(xs)..sort())[xs.length ~/ 2];
    for (var k = 0; k < 6; k++) {
      if (earned[k].isEmpty) continue;
      print('   song ${k + 1}: reached ${earned[k].length}  earned (median) ${med(earned[k])}  quota ${med(dues[k])}  paid ${earned[k].length - (k + 1 < 6 ? earned[k + 1].length : 0)}');
    }
    return;
  }
  for (final bot in bots) {
    var wins = 0;
    final died = List.filled(Run.clearPaydays + 1, 0);
    final withF = <String, int>{}, winsWithF = <String, int>{};
    for (var s = 1; s <= n; s++) {
      final res = play(s * 7919, bot, () => rulesFor(machines.first)..open = _openWhen(machines.first));
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
