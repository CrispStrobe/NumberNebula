import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/player_profile_service.dart';
import '../../../core/theme/space_theme.dart';
import '../../../generated/l10n.dart';

class PlayerProfilesScreen extends StatelessWidget {
  const PlayerProfilesScreen({super.key});
  Future<void> _edit(BuildContext context, PlayerProfileService service,
      [PlayerProfile? player]) async {
    final s = S.of(context)!;
    var editedName = player?.name ?? '';
    final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(player == null ? s.addPlayer : s.renamePlayer),
              content: TextFormField(
                  initialValue: editedName,
                  onChanged: (value) => editedName = value,
                  autofocus: true,
                  maxLength: 30,
                  decoration: InputDecoration(labelText: s.playerName),
                  onFieldSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      Navigator.pop(dialogContext, value.trim());
                    }
                  }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(s.cancel)),
                ElevatedButton(
                    onPressed: () {
                      if (editedName.trim().isNotEmpty) {
                        Navigator.pop(dialogContext, editedName.trim());
                      }
                    },
                    child: Text(s.parentDashboardSave))
              ],
            ));
    if (name == null) return;
    if (player == null) {
      await service.add(name);
    } else {
      await service.rename(player.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlayerProfileService>();
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: SpaceTheme.deepSpace,
      appBar: AppBar(title: Text(s.playersTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(s.playersDescription, style: SpaceTheme.bodyStyle),
        const SizedBox(height: 16),
        for (final player in service.players)
          ListTile(
            leading: Icon(player.id == service.active.id
                ? Icons.check_circle
                : Icons.person_outline),
            title: Text(player.name.isEmpty ? s.originalPlayer : player.name),
            subtitle:
                player.id == service.active.id ? Text(s.currentPlayer) : null,
            onTap: service.busy
                ? null
                : () async {
                    try {
                      await service.activate(player.id);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.playerSwitchFailed)));
                      }
                    }
                  },
            trailing: IconButton(
                tooltip: s.renamePlayer,
                icon: const Icon(Icons.edit),
                onPressed: service.busy
                    ? null
                    : () => _edit(context, service, player)),
          ),
        if (service.busy) const Center(child: CircularProgressIndicator()),
        TextButton.icon(
            onPressed: service.busy ? null : () => _edit(context, service),
            icon: const Icon(Icons.person_add),
            label: Text(s.addPlayer)),
      ]),
    );
  }
}
