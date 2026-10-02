import 'package:flutter/material.dart';
import '../../../core/services/puzzle_session_store.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';
import '../../missions/data/game_pool.dart';
import '../game_registry.dart';

class SavedPuzzlesScreen extends StatefulWidget {
  const SavedPuzzlesScreen({super.key});
  @override
  State<SavedPuzzlesScreen> createState() => _SavedPuzzlesScreenState();
}

class _SavedPuzzlesScreenState extends State<SavedPuzzlesScreen> {
  late Future<List<Map<String, dynamic>>> _sessions;
  @override
  void initState() {
    super.initState();
    _sessions = PuzzleSessionStore.instance.list();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
        backgroundColor: SpaceTheme.deepSpace,
        appBar: AppBar(title: Text(s.savedPuzzlesTitle)),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _sessions,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sessions = snapshot.data!
                  .where((e) => missionGameKeys.contains(e['game']))
                  .toList();
              if (sessions.isEmpty) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.noSavedPuzzles,
                            style: SpaceTheme.bodyStyle,
                            textAlign: TextAlign.center)));
              }
              return ListView(children: [
                for (final session in sessions)
                  ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(gameTitleFor(s, session['game'])),
                      subtitle: Text(s.savedPuzzleLevel(
                          session['grade'], session['level'])),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () async {
                        final builder = gameBuilderFor(session['game']);
                        if (builder == null) return;
                        await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                builder(session['grade'], session['level'])));
                        if (mounted) {
                          setState(() =>
                              _sessions = PuzzleSessionStore.instance.list());
                        }
                      }),
              ]);
            }));
  }
}
