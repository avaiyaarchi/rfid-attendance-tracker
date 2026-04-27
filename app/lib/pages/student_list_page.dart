import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// ─── Student List Page ────────────────────────────────────────────────────────

class StudentListPage extends StatefulWidget {
  const StudentListPage({super.key});
  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  String _search = '';

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
                    child: Text('Students', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add'),
                    onPressed: () => _showAddStudentDialog(context),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search students...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('students')
                    .orderBy('name').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snap.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return _search.isEmpty ||
                        (data['name'] ?? '').toString().toLowerCase().contains(_search) ||
                        (data['roll_no'] ?? '').toString().toLowerCase().contains(_search);
                  }).toList();

                  if (docs.isEmpty) {
                    return Center(child: Text('No students found', style: TextStyle(color: cs.onSurfaceVariant)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final d    = docs[i].data() as Map<String, dynamic>;
                      final id   = docs[i].id;
                      return _StudentTile(data: d, id: id);
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

  void _showAddStudentDialog(BuildContext context) {
    final nameCtrl   = TextEditingController();
    final rollCtrl   = TextEditingController();
    final uidCtrl    = TextEditingController();
    String? selectedClassId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Student', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl,  decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 10),
            TextField(controller: rollCtrl,  decoration: const InputDecoration(labelText: 'Roll Number')),
            const SizedBox(height: 10),
            TextField(controller: uidCtrl,   decoration: const InputDecoration(labelText: 'RFID UID')),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('classes').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final classes = snapshot.data!.docs;

                return DropdownButtonFormField<String>(
                  value: selectedClassId,
                  items: classes.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id, // 👈 store ID
                      child: Text(doc['name']), // 👈 show name
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedClassId = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Select Class'),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('students').add({
                'name':     nameCtrl.text.trim(),
                'roll_no':  rollCtrl.text.trim(),
                'rfid_uid': uidCtrl.text.trim().toUpperCase(),
                'class_id': selectedClassId,
                'photo_url': '',
                'created_at': DateTime.now().toIso8601String(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String id;
  const _StudentTile({required this.data, required this.id});

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final initials = (data['name'] ?? '?').toString().split(' ')
        .take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Text(initials, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
        ),
        title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Roll: ${data['roll_no'] ?? '—'}  •  UID: ${data['rfid_uid'] ?? '—'}',
            style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentProfilePage(studentId: id, data: data)),
        ),
      ),
    );
  }
}

// ─── Student Profile Page ─────────────────────────────────────────────────────

class StudentProfilePage extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> data;
  const StudentProfilePage({super.key, required this.studentId, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final initials = (data['name'] ?? '?').toString().split(' ')
        .take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(data['name'] ?? 'Student'), centerTitle: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: cs.primaryContainer,
                      child: Text(initials, style: TextStyle(color: cs.primary, fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Roll No: ${data['roll_no'] ?? '—'}', style: TextStyle(color: cs.onSurfaceVariant)),
                          Text('UID: ${data['rfid_uid'] ?? '—'}',
                              style: TextStyle(color: cs.onSurfaceVariant, fontFamily: 'monospace', fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Attendance chart
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance_logs')
                  .where('student_id', isEqualTo: studentId)
                  .orderBy('timestamp', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snap) {
                final total   = snap.data?.docs.length ?? 0;
                final present = total;
                // For demo: assume 30 school days in view
                final workDays = 30;
                final pct = workDays == 0 ? 0.0 : present / workDays;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Attendance', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              '${(pct * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontWeight: FontWeight.w700, color: pct >= 0.75 ? Colors.green : Colors.red, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 140,
                          child: PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value: present.toDouble(),
                                  color: Colors.green,
                                  title: 'Present\n$present',
                                  radius: 55,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                PieChartSectionData(
                                  value: (workDays - present).toDouble().clamp(0, double.infinity),
                                  color: Colors.red.shade200,
                                  title: 'Absent\n${(workDays - present).clamp(0, workDays)}',
                                  radius: 55,
                                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Recent attendance history
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Recent History', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('attendance_logs')
                          .where('student_id', isEqualTo: studentId)
                          .orderBy('timestamp', descending: true)
                          .limit(10)
                          .snapshots(),
                      builder: (context, snap) {
                        if (!snap.hasData || snap.data!.docs.isEmpty) {
                          return const Text('No records found', style: TextStyle(color: Colors.grey));
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snap.data!.docs.length,
                          itemBuilder: (_, i) {
                            final d = snap.data!.docs[i].data() as Map<String, dynamic>;
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              title: Text(d['date'] ?? '', style: const TextStyle(fontSize: 13)),
                              trailing: Text(d['time'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
