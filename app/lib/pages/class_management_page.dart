// ─── Class Management Page ────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ClassManagementPage extends StatelessWidget {
  const ClassManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Classes', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Class'),
                    onPressed: () => _showAddClass(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('classes').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 64, color: cs.onSurfaceVariant.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text('No classes yet', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final d  = docs[i].data() as Map<String, dynamic>;
                      final id = docs[i].id;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('students')
                            .where('class_id', isEqualTo: id)
                            .snapshots(),
                        builder: (context, studentSnap) {
                          final studentCount = studentSnap.data?.docs.length ?? 0;

                          return Card(
                            child: ListTile(
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.school, color: cs.primary),
                              ),
                              title: Text(
                                d['name'] ?? 'Unnamed',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$studentCount students • ${d['teacher'] ?? 'No teacher'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                                onSelected: (v) async {
                                  if (v == 'delete') {
                                    await FirebaseFirestore.instance
                                        .collection('classes')
                                        .doc(id)
                                        .delete();
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClass(BuildContext context) {
    final nameCtrl    = TextEditingController();
    final teacherCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New Class', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl,    decoration: const InputDecoration(labelText: 'Class Name')),
            const SizedBox(height: 10),
            TextField(controller: teacherCtrl, decoration: const InputDecoration(labelText: 'Teacher Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('classes').add({
                'name':        nameCtrl.text.trim(),
                'teacher':     teacherCtrl.text.trim(),
                'created_at':  DateTime.now().toIso8601String(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
