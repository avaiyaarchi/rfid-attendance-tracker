import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveAttendancePage extends StatefulWidget {
  const LiveAttendancePage({super.key});
  @override
  State<LiveAttendancePage> createState() => _LiveAttendancePageState();
}

class _LiveAttendancePageState extends State<LiveAttendancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _scanning = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Live Attendance', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
                        Text(
                          DateFormat('EEEE, MMM d').format(DateTime.now()),
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  // Pulse indicator
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _scanning
                            ? Colors.green.withOpacity(0.1 + _pulseController.value * 0.1)
                            : cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _scanning ? Colors.green : cs.outline,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: _scanning ? Colors.green : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _scanning ? 'Live' : 'Paused',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _scanning ? Colors.green : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Real-time attendance list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance_logs')
                    .where('date', isEqualTo: today)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.contactless, size: 64, color: cs.onSurfaceVariant.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No scans yet',
                            style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Waiting for RFID cards to be scanned...',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snap.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d       = docs[i].data() as Map<String, dynamic>;
                      final isValid = d['valid'] == true;
                      final isNew   = i == 0; // animate the most recent scan

                      return _AttendanceCard(
                        data: d,
                        isValid: isValid,
                        isNew: isNew,
                      );
                    },
                  );
                },
              ),
            ),

            // Manual attendance button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manual Entry Fallback'),
                  onPressed: () => _showManualEntry(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualEntry(BuildContext context) {
    final ctrl = TextEditingController();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manual UID Entry', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'RFID UID'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final uid = ctrl.text.trim().toUpperCase();
                  if (uid.isEmpty) return;

                  final now = DateTime.now();

                  // 🔍 Check student in Firestore
                  final query = await FirebaseFirestore.instance
                      .collection('students')
                      .where('rfid_uid', isEqualTo: uid)
                      .limit(1)
                      .get();

                  Map<String, dynamic> data = {
                    'uid': uid,
                    'timestamp': now.toIso8601String(),
                    'date': DateFormat('yyyy-MM-dd').format(now),
                    'time': DateFormat('HH:mm:ss').format(now),
                    'status': 'present',
                    'manual': true,
                  };

                  if (query.docs.isNotEmpty) {
                    // ✅ Student found
                    final student = query.docs.first;
                    final studentData = student.data();

                    final existing = await FirebaseFirestore.instance
                        .collection('attendance_logs')
                        .where('student_id', isEqualTo: student.id)
                        .where('date', isEqualTo: today)
                        .limit(1)
                        .get();

                    if (existing.docs.isNotEmpty) {
                      // already marked today
                      if (ctx.mounted) Navigator.pop(ctx);
                      return;
                    }

                    data['valid'] = true;
                    data['student_id'] = student.id;
                    data['student_name'] = studentData['name'];
                    data['class_id'] = studentData['class_id'];
                  } else {
                    // ❌ Unknown UID
                    data['valid'] = false;
                    data['student_name'] = 'Unknown';
                  }

                  // 📤 Save to Firestore
                  await FirebaseFirestore.instance
                      .collection('attendance_logs')
                      .add(data);

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Log Attendance'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isValid, isNew;
  const _AttendanceCard({required this.data, required this.isValid, required this.isNew});

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (widget.isNew) _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d       = widget.data;
    final color   = widget.isValid ? Colors.green : Colors.red;
    final cs      = Theme.of(context).colorScheme;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
          .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut)),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(_anim),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Status dot
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.isValid ? Icons.check_circle : Icons.person_off,
                    color: color, size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['student_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'UID: ${d['uid'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      d['time'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.isValid ? 'Present' : 'Unknown',
                        style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
