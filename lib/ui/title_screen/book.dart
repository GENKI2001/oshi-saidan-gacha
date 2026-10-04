// The book (図鑑): every goods, the ones not found yet as silhouettes.

part of '../title_screen.dart';

class BookScreen extends StatelessWidget {
  final Meta meta;
  const BookScreen({super.key, required this.meta});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.night,
    body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
      child: SafeArea(bottom: false, child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CustomScrollView(
          slivers: [
            // the header scrolls away with the goods
            SliverToBoxAdapter(child: ScreenHeader('図鑑', note: '${meta.seen.length} / ${figures.length}')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverGrid.count(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final f in figures)
              GestureDetector(
                onTap: meta.seen.contains(f.id)
                    ? () {
                        Sfx.play('tap');
                        showFigureInfo(context, f);
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: C.cream,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: meta.seen.contains(f.id) ? C.rarity(f.rarity) : C.woodDark, width: 3),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: meta.seen.contains(f.id)
                      ? FigureArt(f, size: 100)
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                !meta.figureOpen(f) ? const Color(0xFF3A2D52) : const Color(0xFF5A4A6A),
                                BlendMode.srcIn,
                              ),
                              child: FigureArt(f, size: 100),
                            ),
                            // not in the gacha yet: the machine whose first clear brings it in
                            if (!meta.figureOpen(f))
                              Text(
                                '${machineById[f.from]!.name}\nでクリア',
                                textAlign: TextAlign.center,
                                style: outlined(12, Colors.white, width: 3),
                              ),
                          ],
                        ),
                ),
              ),
          ],
              ),
            ),
          ],
        ),
      ),
    ))),
  );
}
