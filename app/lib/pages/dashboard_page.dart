import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'reports_page.dart';
import 'student_list_page.dart';
import 'live_attendance_page.dart';
import 'class_management_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final cs    = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_greeting()}!',
                    style: GoogleFonts.nunito(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  Text(
                    'Attendance Dashboard',
                    style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Date chip
                  Text(
                    DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Stats cards (real-time)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance_logs')
                        .where('date', isEqualTo: today)
                        .snapshots(),
                    builder: (context, snap) {
                      final presentCount = snap.data?.docs.length ?? 0;

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('students').snapshots(),
                        builder: (context, studentSnap) {
                          final totalCount  = studentSnap.data?.docs.length ?? 0;
                          final absentCount = totalCount - presentCount;
                          final pct = totalCount == 0 ? 0.0 : presentCount / totalCount;

                          return Column(
                            children: [
                              Row(
                                children: [
                                  _StatCard(
                                    label: 'Total Students',
                                    value: '$totalCount',
                                    icon: Icons.people,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  _StatCard(
                                    label: 'Present Today',
                                    value: '$presentCount',
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  _StatCard(
                                    label: 'Absent Today',
                                    value: '$absentCount',
                                    icon: Icons.cancel,
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Attendance progress bar
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Attendance Rate', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                                          Text(
                                            '${(pct * 100).toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: cs.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          minHeight: 10,
                                          backgroundColor: cs.primaryContainer,
                                          valueColor: AlwaysStoppedAnimation(cs.primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Quick Actions',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  // Quick action grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.4,
                    children: [
                      _QuickAction(
                        icon: Icons.contactless,
                        label: 'Take Attendance',
                        color: cs.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => LiveAttendancePage()),
                          );
                        },
                      ),

                      _QuickAction(
                        icon: Icons.bar_chart,
                        label: 'View Reports',
                        color: Colors.indigo,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReportsPage()),
                          );
                        },
                      ),

                      _QuickAction(
                        icon: Icons.school,
                        label: 'Manage Classes',
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ClassManagementPage()),
                          );
                        },
                      ),

                      _QuickAction(
                        icon: Icons.person_add,
                        label: 'Add Student',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => StudentListPage()),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text(
                    'Recent Scans',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  // Recent scans list
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance_logs')
                        .orderBy('timestamp', descending: true)
                        .limit(5)
                        .snapshots(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('No scans yet today'),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = docs[i].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: d['valid'] == true
                                  ? Colors.green.withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                              child: Icon(
                                d['valid'] == true ? Icons.check : Icons.close,
                                color: d['valid'] == true ? Colors.green : Colors.red,
                                size: 18,
                              ),
                            ),
                            title: Text(d['student_name'] ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text(d['uid'] ?? '', style: const TextStyle(fontSize: 12)),
                            trailing: Text(d['time'] ?? '', style: const TextStyle(fontSize: 12)),
                          );
                        },
                      );
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap,});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }
}
