import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xta/database/entities.dart';
import 'package:xta/database/repository.dart';
import 'package:xta/generated/l10n.dart';

Future<ProfileNote?> loadProfileNote(String userId) async {
  final database = await Repository.readOnly();
  final rows = await database.query(tableProfileNote, where: 'id = ?', whereArgs: [userId], limit: 1);
  if (rows.isEmpty) {
    return null;
  }
  return ProfileNote.fromMap(rows.first);
}

Future<void> saveProfileNote(String userId, String note) async {
  final trimmed = note.trim();
  final database = await Repository.writable();

  if (trimmed.isEmpty) {
    await database.delete(tableProfileNote, where: 'id = ?', whereArgs: [userId]);
    return;
  }

  await database.insert(
    tableProfileNote,
    ProfileNote(id: userId, note: trimmed, updatedAt: DateTime.now()).toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// Private note card shown on a profile — local only, never synced.
class ProfileNoteCard extends StatefulWidget {
  final String userId;

  const ProfileNoteCard({super.key, required this.userId});

  @override
  State<ProfileNoteCard> createState() => _ProfileNoteCardState();
}

class _ProfileNoteCardState extends State<ProfileNoteCard> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final note = await loadProfileNote(widget.userId);
    if (!mounted) {
      return;
    }
    _controller.text = note?.note ?? '';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await saveProfileNote(widget.userId, _controller.text);
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    if (_loading) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.profile_note_title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.profile_note_hint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(l10n.profile_note_save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
