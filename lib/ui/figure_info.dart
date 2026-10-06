// A goods' details in a bottom sheet (tapped on the altar or in the book).

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../logic/defs.dart';
import '../logic/run.dart';
import 'widgets.dart';

Future<void> showFigureInfo(BuildContext context, FigureDef d, [Fig? f, Run? run]) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(14),
      child: Panel(
        child: Row(
        children: [
          FigureArt(d, size: 110),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  d.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.ink),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RarityStars(d.rarity, size: 18),
                      Text(
                        en ? d.tags.map(tr).join(' · ') : d.tags.map((t) => '「$t」').join(),
                        style: const TextStyle(color: C.ink, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  d.description,
                  style: const TextStyle(fontSize: 15, height: 1.4, color: C.ink, fontWeight: FontWeight.w600),
                ),
                if (f != null && f.stack > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(en ? 'Stacked: effects ×${f.stack}' : '重ねて強化中：効果が ×${f.stack}', style: outlined(15, const Color(0xFFE6A700), stroke: Colors.white, width: 3)),
                  ),
                if (f != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    en
                        ? 'On the altar for ${f.age} spins${f.lastGain != 0 ? ' · last spin ${f.lastGain} Hearts' : ''}'
                        : '置いてから ${f.age} 回転${f.lastGain != 0 ? '・さっきのハート ${f.lastGain}' : ''}',
                    style: const TextStyle(color: C.woodDark, fontWeight: FontWeight.w800),
                  ),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    ),
  );
}
