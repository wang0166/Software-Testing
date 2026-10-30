import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

/// Editable *presentation entries* for the personal top-ten panel.
/// They belong to the signed-in user and are not edits to the source task.
class PersonalBoardEntry {
  final String title;
  final String detail;
  const PersonalBoardEntry({required this.title, required this.detail});

  Map<String, String> toJson() => {'title': title, 'detail': detail};

  static PersonalBoardEntry fromJson(dynamic value) {
    final data = Map<String, dynamic>.from(value as Map);
    return PersonalBoardEntry(
      title: (data['title'] ?? '').toString(),
      detail: (data['detail'] ?? '').toString(),
    );
  }
}

class PersonalBoardStorage {
  static String key(int userId) => 'pandora_personal_top10_v17_$userId';

  /// null means the user has not customized the panel yet.
  /// [] means they intentionally cleared it.
  static Future<List<PersonalBoardEntry>?> read(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key(userId));
    if (raw == null) {
      // Preserve old on-device notes when upgrading from the V1.6 board.
      // The user can now edit their titles and details in the new editor.
      final legacy = prefs.getStringList('pandora_board_notes_${userId}_03');
      if (legacy != null && legacy.isNotEmpty) {
        return legacy.take(10).map((note) =>
          PersonalBoardEntry(title: note, detail: '')).toList();
      }
      return null;
    }
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map(PersonalBoardEntry.fromJson)
          .take(10)
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> write(int userId, List<PersonalBoardEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
      key(userId),
      jsonEncode(items.take(10).map((item) => item.toJson()).toList()),
    );
  }
}

class PersonalBoardEditorPage extends StatefulWidget {
  final int userId;
  final List<PersonalBoardEntry> initial;
  const PersonalBoardEditorPage({
    super.key,
    required this.userId,
    required this.initial,
  });

  @override
  State<PersonalBoardEditorPage> createState() => _PersonalBoardEditorPageState();
}

class _PersonalBoardEditorPageState extends State<PersonalBoardEditorPage> {
  late final List<PersonalBoardEntry> _entries;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _entries = List<PersonalBoardEntry>.from(widget.initial.take(10));
  }

  Future<void> _editAt([int? index]) async {
    final existing = index == null ? null : _entries[index];
    final title = TextEditingController(text: existing?.title ?? '');
    final detail = TextEditingController(text: existing?.detail ?? '');
    final updated = await showDialog<PersonalBoardEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(index == null ? '添加个人重点信息' : '修改信息内容'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: title,
                maxLength: 80,
                decoration: const InputDecoration(labelText: '信息标题'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: detail,
                minLines: 3,
                maxLines: 5,
                maxLength: 400,
                decoration: const InputDecoration(labelText: '信息内容 / 工作细节'),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('请填写信息标题')),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                PersonalBoardEntry(
                  title: title.text.trim(),
                  detail: detail.text.trim(),
                ),
              );
            },
            child: const Text('应用修改'),
          ),
        ],
      ),
    );
    title.dispose();
    detail.dispose();
    if (!mounted || updated == null) return;
    setState(() {
      if (index == null) {
        if (_entries.length < 10) _entries.add(updated);
      } else {
        _entries[index] = updated;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await PersonalBoardStorage.write(widget.userId, _entries);
      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('个人信息保存失败，请重试')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('编辑个人10大信息')),
    body: SafeArea(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFE7EEF2),
          child: const Text(
            '可随时修改标题和工作细节、调整顺序、删除或新增，最多10条。'
            '\n当前编辑的是本人四宫格的展示信息，保存在本机；不会擅自改动服务端任务或他人的数据。',
            style: TextStyle(fontSize: 12, color: Palette.deep, height: 1.55),
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(child: Text('暂无个人重点信息，点击下方添加'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  buildDefaultDragHandles: true,
                  itemCount: _entries.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    setState(() {
                      final moved = _entries.removeAt(oldIndex);
                      _entries.insert(newIndex, moved);
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _entries[index];
                    return Card(
                      key: ObjectKey(item),
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: const Color(0xFFE2EEED),
                          child: Text('${index + 1}', style: const TextStyle(
                            color: Palette.deep, fontSize: 12)),
                        ),
                        title: Text(item.title, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(item.detail.isEmpty ? '未填写细节' : item.detail,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _editAt(index),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 19),
                          tooltip: '删除此条',
                          onPressed: () => setState(() => _entries.removeAt(index)),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _entries.length >= 10 ? null : () => _editAt(),
              icon: const Icon(Icons.add),
              label: Text('新增信息 (${_entries.length}/10)'),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('保存面板内容'),
            )),
          ]),
        ),
      ]),
    ),
  );
}
