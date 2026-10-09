import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeManagementScreen extends StatefulWidget {
  const NoticeManagementScreen({super.key});

  @override
  State<NoticeManagementScreen> createState() => _NoticeManagementScreenState();
}

class _NoticeManagementScreenState extends State<NoticeManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        title: Text(
          "Notice Management",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          PopupMenuButton<String>(
            color: const Color(0xff1E293B),

            icon: const Icon(Icons.more_vert, color: Colors.white),

            onSelected: (value) {
              if (value == "add") {
                _showNoticeDialog();
              }
            },

            itemBuilder: (context) => [
              PopupMenuItem(
                value: "add",

                child: Row(
                  children: [
                    const Icon(Icons.add, color: Colors.white),

                    const SizedBox(width: 12),

                    Text(
                      "Add Notice",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('notices').snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Failed to load notices",
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

            if (aImportant != bImportant) {
              return bImportant ? 1 : -1;
            }

            // ==========================================================
            // WITHIN SAME PRIORITY:
            // LATEST CREATED NOTICE FIRST
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
            padding: const EdgeInsets.all(20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  "Published Notices",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  "Manage notices visible to library students",
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),

                if (sortedDocuments.isEmpty) _emptyNoticeCard(),

                ...sortedDocuments.map((document) {
                  final data = document.data() as Map<String, dynamic>;

                  final title = data['title']?.toString() ?? "-";

                  final message = data['message']?.toString() ?? "-";

                  final date = data['date']?.toString() ?? "-";

                  final isImportant = data['isImportant'] == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),

                    child: _noticeCard(
                      documentId: document.id,
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
    );
  }

  Widget _emptyNoticeCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white24),
      ),

      child: Column(
        children: [
          const Icon(Icons.notifications_none, color: Colors.white54, size: 45),

          const SizedBox(height: 12),

          Text(
            "No notices published yet",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard({
    required String documentId,
    required String title,
    required String message,
    required String date,
    required bool isImportant,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(
          color: isImportant
              ? Colors.orangeAccent.withValues(alpha: 0.60)
              : Colors.white24,
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                height: 45,
                width: 45,

                decoration: BoxDecoration(
                  color: isImportant
                      ? Colors.orange.withValues(alpha: 0.20)
                      : Colors.blue.withValues(alpha: 0.20),

                  borderRadius: BorderRadius.circular(13),
                ),

                child: Icon(
                  isImportant
                      ? Icons.priority_high_rounded
                      : Icons.campaign_outlined,

                  color: isImportant ? Colors.orangeAccent : Colors.blueAccent,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (isImportant) ...[
                      const SizedBox(height: 5),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.20),

                          borderRadius: BorderRadius.circular(10),
                        ),

                        child: Text(
                          "IMPORTANT",
                          style: GoogleFonts.poppins(
                            color: Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              PopupMenuButton<String>(
                color: const Color(0xff1E293B),

                icon: const Icon(Icons.more_vert, color: Colors.white70),

                onSelected: (value) {
                  if (value == "edit") {
                    _showNoticeDialog(
                      documentId: documentId,
                      existingTitle: title,
                      existingMessage: message,
                      existingImportant: isImportant,
                    );
                  }

                  if (value == "delete") {
                    _showDeleteDialog(documentId, title);
                  }
                },

                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: "edit",

                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, color: Colors.white),

                        const SizedBox(width: 10),

                        Text(
                          "Edit",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: "delete",

                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),

                        const SizedBox(width: 10),

                        Text(
                          "Delete",
                          style: GoogleFonts.poppins(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white38,
                size: 15,
              ),

              const SizedBox(width: 7),

              Text(
                date,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showNoticeDialog({
    String? documentId,
    String? existingTitle,
    String? existingMessage,
    bool existingImportant = false,
  }) async {
    final titleController = TextEditingController(text: existingTitle ?? "");

    final messageController = TextEditingController(
      text: existingMessage ?? "",
    );

    bool isImportant = existingImportant;

    final bool isEditing = documentId != null;

    await showDialog(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1E293B),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: Text(
                isEditing ? "Edit Notice" : "Add Notice",

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    TextField(
                      controller: titleController,

                      style: GoogleFonts.poppins(color: Colors.white),

                      decoration: InputDecoration(
                        labelText: "Notice Title",

                        labelStyle: GoogleFonts.poppins(color: Colors.white70),

                        prefixIcon: const Icon(
                          Icons.title,
                          color: Colors.white70,
                        ),

                        filled: true,

                        fillColor: Colors.white.withValues(alpha: 0.08),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: messageController,

                      maxLines: 5,

                      style: GoogleFonts.poppins(color: Colors.white),

                      decoration: InputDecoration(
                        labelText: "Notice Message",

                        alignLabelWithHint: true,

                        labelStyle: GoogleFonts.poppins(color: Colors.white70),

                        filled: true,

                        fillColor: Colors.white.withValues(alpha: 0.08),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,

                      value: isImportant,

                      activeColor: Colors.orangeAccent,

                      title: Text(
                        "Mark as Important",

                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),

                      onChanged: (value) {
                        setDialogState(() {
                          isImportant = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text("CANCEL"),
                ),

                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();

                    final message = messageController.text.trim();

                    if (title.isEmpty || message.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Please enter notice title and message",
                          ),
                        ),
                      );

                      return;
                    }

                    try {
                      final now = DateTime.now();

                      final date =
                          "${now.day.toString().padLeft(2, '0')} "
                          "${_monthName(now.month)} "
                          "${now.year}";

                      if (isEditing) {
                        await _firestore
                            .collection('notices')
                            .doc(documentId)
                            .update({
                              'title': title,
                              'message': message,
                              'date': date,
                              'isImportant': isImportant,
                            });
                      } else {
                        await _firestore.collection('notices').add({
                          'title': title,
                          'message': message,
                          'date': date,
                          'isImportant': isImportant,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                      }

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing
                                ? "Notice Updated Successfully"
                                : "Notice Published Successfully",
                          ),

                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Failed to save notice: $e"),

                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },

                  child: Text(isEditing ? "UPDATE" : "PUBLISH"),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    messageController.dispose();
  }

  Future<void> _showDeleteDialog(String documentId, String noticeTitle) async {
    await showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff1E293B),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: Text(
            "Delete Notice",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          content: Text(
            'Are you sure you want to delete "$noticeTitle"?',

            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text("CANCEL"),
            ),

            ElevatedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);

                try {
                  await _firestore
                      .collection('notices')
                      .doc(documentId)
                      .delete();

                  if (!mounted) {
                    return;
                  }

                  navigator.pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Notice Deleted Successfully"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } catch (e) {
                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Failed to delete notice: $e"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },

              icon: const Icon(Icons.delete_outline),

              label: const Text("DELETE"),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  String _monthName(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return months[month - 1];
  }
}
