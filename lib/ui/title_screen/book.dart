// コレクション: everything collected so far, on three tabs — the goods (the old 図鑑), the songs
// (played right here) and the photos (the illustrations, opened by playing).

part of '../title_screen.dart';

class CollectionScreen extends StatefulWidget {
  final Meta meta;
  const CollectionScreen({super.key, required this.meta});
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

/// One song in the collection: its track, a name, and whether it has been heard yet.
typedef _Song = ({String track, String name, bool open, String hint});

/// One photo: the picture, its caption, and whether it is open yet (and how to open it).
typedef _Photo = ({String asset, String name, bool open, String hint, bool portrait});

class _CollectionScreenState extends State<CollectionScreen> {
  int _tab = 0;
  String? _playing;

  Meta get meta => widget.meta;

  List<_Song> get _songs {
    final heardSong = meta.machineSongs.values.any((v) => v >= 1);
    final byTrack = <String, List<MachineDef>>{};
    for (final m in machines) {
      (byTrack[m.bgm] ??= []).add(m);
    }
    return [
      (track: 'title', name: tr('タイトル・ぷりパレガチャ'), open: true, hint: ''),
      (track: 'select', name: tr('ガチャえらび'), open: true, hint: ''),
      for (final e in byTrack.entries)
        if (e.key != 'title')
          (
            track: e.key,
            name: e.value.map((m) => m.name).join(en ? ' / ' : '・'),
            open: e.value.any(meta.unlocked),
            hint: en ? 'Unlock ${e.value.first.name}' : '${e.value.first.name}を 解放する',
          ),
      (track: 'clear', name: tr('曲クリア'), open: heardSong, hint: tr('1曲 ノルマを達成する')),
      (track: 'result', name: tr('リザルト'), open: meta.runs > 0, hint: tr('ライブを1回 終える')),
    ];
  }

  List<_Photo> get _photos {
    String hint(String id) => achievementById[id]?.text ?? '';
    return [
      (asset: 'assets/ui/title_bg.jpg', name: tr('キービジュアル'), open: true, hint: '', portrait: false),
      (asset: 'assets/ui/clear_bg.jpg', name: tr('ライブ大成功'), open: meta.clears > 0, hint: tr('ライブを成功させる'), portrait: false),
      for (final m in members)
        for (final (face, ach, label) in const [('a', '_altar', '笑顔'), ('b', '_clear', 'だいすき'), ('c', '_place', 'てれ顔')])
          (
            asset: portrait(m, face: face),
            name: en ? '${tr(m)} (${tr(label)})' : '$m（$label）',
            open: meta.achieved.contains('${speakerId[m]}$ach'),
            hint: en
                ? 'Achievement "${achievementById['${speakerId[m]}$ach']?.title ?? ''}"\n${hint('${speakerId[m]}$ach')}'
                : '実績「${achievementById['${speakerId[m]}$ach']?.title ?? ''}」\n${hint('${speakerId[m]}$ach')}',
            portrait: true,
          ),
      (asset: 'assets/ui/boss_1.png', name: tr('つむぎ'), open: meta.runs > 0, hint: tr('ライブを1回 終える'), portrait: true),
      (asset: 'assets/ui/jama_a.webp', name: tr('転売ヤー カイシメ'), open: meta.jamWins > 0, hint: tr('転売ヤーから 祭壇をまもる'), portrait: true),
    ];
  }

  String get _note => switch (_tab) {
    0 => '${meta.seen.length} / ${figures.length}',
    1 => '${_songs.where((s) => s.open).length} / ${_songs.length}',
    _ => '${_photos.where((p) => p.open).length} / ${_photos.length}',
  };

  void _play(_Song s) {
    if (!s.open) return;
    Sfx.play('tap');
    setState(() => _playing = s.track);
    Bgm.play('bgm_${s.track}', fromStart: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.night,
    body: Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/venue_1.jpg'), fit: BoxFit.cover)),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              slivers: [
                // the header and the tabs scroll away with the list
                SliverToBoxAdapter(child: ScreenHeader(tr('コレクション'), note: _note)),
                SliverToBoxAdapter(child: _tabs()),
                ...switch (_tab) {
                  0 => [_goods()],
                  1 => [_songList()],
                  _ => [_photoGrid()],
                },
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _tabs() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Row(
      children: [
        for (final (k, label, icon) in const [(0, 'グッズ', Icons.redeem_rounded), (1, 'BGM', Icons.music_note_rounded), (2, '写真', Icons.photo_rounded)])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                onTap: () {
                  if (_tab == k) return;
                  Sfx.play('toggle');
                  setState(() => _tab = k);
                },
                // the open tab is the pink tag, the others white tags (the button look)
                child: TagSurface(
                  fill: _tab == k ? C.pink : null,
                  stitch: _tab == k ? Colors.white.withValues(alpha: 0.75) : C.tagStitch,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 18, color: _tab == k ? Colors.white : C.tagText),
                      const SizedBox(width: 4),
                      Text(tr(label), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _tab == k ? Colors.white : C.tagText)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  // ── グッズ: every goods, the ones not found yet as silhouettes ──
  Widget _goods() => SliverPadding(
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
                        if (!meta.figureOpen(f) && f.from != null)
                          Text(
                            en ? 'Clear\n${machineById[f.from]!.name}' : '${machineById[f.from]!.name}\nでクリア',
                            textAlign: TextAlign.center,
                            style: outlined(12, Colors.white, width: 3),
                          ),
                      ],
                    ),
            ),
          ),
      ],
    ),
  );

  // ── BGM: tap one to play it here ──
  Widget _songList() => SliverPadding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
    sliver: SliverList.list(
      children: [
        for (final s in _songs)
          GestureDetector(
            onTap: () => _play(s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: s.open ? (_playing == s.track ? const [Color(0xFFFFE3F0), Color(0xFFFFF3B0)] : const [Colors.white, Color(0xFFFFF0F7)]) : const [Color(0xFFF2EEF4), Color(0xFFE8E2EC)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _playing == s.track ? C.pink : (s.open ? C.pinkLine : const Color(0xFFB9AEC0)), width: 3),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: s.open ? C.pink : const Color(0xFFB9AEC0), border: Border.all(color: Colors.white, width: 2.5)),
                    child: Icon(s.open ? (_playing == s.track ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded) : Icons.lock_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.open ? s.name : '？？？', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.open ? C.ink : const Color(0xFF9A8FA2))),
                        if (!s.open) Text(s.hint, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9A8FA2))),
                        if (_playing == s.track) Text(tr('♪ 再生中'), style: outlined(12, C.pink, stroke: Colors.white, width: 2.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  // ── 写真: the illustrations, opened by playing; tap one to see it big ──
  Widget _photoGrid() => SliverPadding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
    sliver: SliverGrid.count(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
      children: [
        for (final p in _photos)
          GestureDetector(
            onTap: () {
              Sfx.play('tap');
              p.open ? _viewPhoto(p) : _photoHint(p);
            },
            child: Container(
              decoration: BoxDecoration(
                color: p.open ? Colors.white : const Color(0xFF3A2D52),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.open ? Colors.white : const Color(0xFF6A5A82), width: 3),
                boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    p.open
                        ? Image.asset(p.asset, fit: BoxFit.cover, alignment: p.portrait ? Alignment.topCenter : Alignment.center)
                        : const ColoredBox(color: Color(0xFF3A2D52), child: Icon(Icons.lock_rounded, color: Color(0xFF8E7FA8), size: 34)),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(p.open ? p.name : '？？？', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  void _viewPhoto(_Photo p) => showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.9),
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.of(ctx).pop(),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: InteractiveViewer(maxScale: 4, child: Center(child: Image.asset(p.asset, fit: BoxFit.contain)))),
              Padding(padding: const EdgeInsets.all(12), child: Text(p.name, style: outlined(20, Colors.white, stroke: C.pink, width: 4))),
            ],
          ),
        ),
      ),
    ),
  );

  void _photoHint(_Photo p) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(en ? 'To unlock: ${p.hint}' : '解放条件：${p.hint}'), duration: const Duration(seconds: 2)));
}
