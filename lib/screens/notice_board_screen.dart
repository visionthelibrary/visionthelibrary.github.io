import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';

class NoticeBoardScreen extends StatelessWidget {
  const NoticeBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notices')
                .snapshots(),

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Failed to load notices",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: Colors.redAccent),
                  ),
                );
              }

              final documents = snapshot.data?.docs ?? [];

              final sortedDocuments = [...documents];

              sortedDocuments.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                // ==========================================================
                // IMPORTANT NOTICE PRIORITY
                // ==========================================================

                final bool aImportant = aData['isImportant'] == true;

                final bool bImportant = bData['isImportant'] == true;

                // Important notices always come first.
                if (aImportant != bImportant) {
                  return bImportant ? 1 : -1;
                }

                // ==========================================================
                // SAME PRIORITY:
                // LATEST NOTICE FIRST
                // ==========================================================

                final aCreated = aData['createdAt'];
                final bCreated = bData['createdAt'];

                if (aCreated is Timestamp && bCreated is Timestamp) {
                  return bCreated.compareTo(aCreated);
                }

                // ==========================================================
                // FALLBACK
                // ==========================================================

                if (aCreated is Timestamp) {
                  return -1;
                }

                if (bCreated is Timestamp) {
                  return 1;
                }

                return 0;
              });

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),

                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "Notice Board",

                            textAlign: TextAlign.center,

                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(width: 48),
                      ],
                    ),

                    const SizedBox(height: 25),

                    if (sortedDocuments.isEmpty) _emptyNoticeCard(),

                    ...sortedDocuments.map((document) {
                      final data = document.data() as Map<String, dynamic>;

                      final title = data['title']?.toString() ?? "-";

                      final message = data['message']?.toString() ?? "";

                      final date = data['date']?.toString() ?? "-";

                      final isImportant = data['isImportant'] == true;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),

                        child: noticeCard(
                          title: title,
                          message: message,
                          date: date,
                          isImportant: isImportant,
                        ),
                      );
                    }),

                    const SizedBox(height: 15),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _emptyNoticeCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          children: [
            const Icon(
              Icons.notifications_none,
              color: Colors.white54,
              size: 48,
            ),

            const SizedBox(height: 12),

            Text(
              "No notices available",

              textAlign: TextAlign.center,

              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget noticeCard({
    required String title,
    required String message,
    required String date,
    required bool isImportant,
  }) {
    final Color accentColor = isImportant
        ? Colors.orangeAccent
        : Colors.blueAccent;

    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 14,
            height: 14,

            margin: const EdgeInsets.only(top: 5),

            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Expanded(
                      child: Text(
                        title,

                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (isImportant)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.18),

                          borderRadius: BorderRadius.circular(10),
                        ),

                        child: Text(
                          "IMPORTANT",

                          style: GoogleFonts.poppins(
                            color: Colors.orangeAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),

                  Text(
                    message,

                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Text(
                  date,

                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
