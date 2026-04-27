import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _range = 'weekly';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Text('Reports & Analytics', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'daily',   label: Text('Daily')),
                      ButtonSegment(value: 'weekly',  label: Text('Weekly')),
                      ButtonSegment(value: 'monthly', label: Text('Monthly')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) => setState(() => _range = s.first),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Bar chart — last 7 days attendance
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attendance Trend', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Last 7 days', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 180,
                            child: _AttendanceTrendChart(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Summary stats from Firestore
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('attendance_logs').snapshots(),
                    builder: (context, snap) {
                      final total = snap.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          _ReportStatCard(label: 'Total Scans',  value: '$total',  icon: Icons.contactless),
                          const SizedBox(width: 12),
                          _ReportStatCard(label: 'Valid Scans',
                            value: '${snap.data?.docs.where((d) => (d.data() as Map)['valid'] == true).length ?? 0}',
                            icon: Icons.check_circle_outline),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Export buttons
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Export Report', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                                  label: const Text('Export PDF'),
                                  onPressed: () => _exportPdf(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.table_chart, size: 18),
                                  label: const Text('Export Excel'),
                                  onPressed: () => _exportExcel(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upload Results', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.upload_file),
                                  label: Text('Upload Result PDF'),
                                  onPressed: () => (context),
                                )
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ],

                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Recent logs table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent Logs', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 10),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('attendance_logs')
                                .orderBy('timestamp', descending: true)
                                .limit(20)
                                .snapshots(),
                            builder: (context, snap) {
                              if (!snap.hasData) return const CircularProgressIndicator();
                              return Column(
                                children: snap.data!.docs.map((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return ListTile(
                                    dense: true,
                                    title: Text(d['student_name'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    subtitle: Text('${d['date'] ?? ''} ${d['time'] ?? ''}', style: const TextStyle(fontSize: 11)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: d['valid'] == true ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        d['valid'] == true ? 'Valid' : 'Unknown',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: d['valid'] == true ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportPdf(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export — integrate pdf package with attendance data')),
    );
  }

  void _exportExcel(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel export — integrate excel package with attendance data')),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _ReportStatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.primary)),
              Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceTrendChart extends StatelessWidget {
  // Generates mock last-7-days data; replace with real Firestore queries.
  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final days = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DateFormat('E').format(d);
    });
    // Placeholder values — replace with real aggregation
    final values = [18.0, 22.0, 20.0, 25.0, 19.0, 23.0, 21.0];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 30,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(days[v.toInt()], style: const TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: cs.primary,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        )),
      ),
    );
  }
}
