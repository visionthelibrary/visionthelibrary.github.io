import 'package:cloud_firestore/cloud_firestore.dart';

class MembershipService {
  MembershipService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Checks the student's membership and automatically
  /// changes an expired Active membership to Inactive.
  ///
  /// Rules:
  /// Active + Valid Till is before today
  ///     -> Inactive
  ///     -> validTill = null
  ///
  /// Inactive
  ///     -> validTill remains null
  ///
  /// Active + Valid Till is today/future
  ///     -> remains Active
  static Future<Map<String, dynamic>?> checkAndUpdateMembership(
    String libraryId,
  ) async {
    try {
      final studentRef = _firestore.collection('students').doc(libraryId);

      final document = await studentRef.get();

      if (!document.exists) {
        return null;
      }

      final data = document.data();

      if (data == null) {
        return null;
      }

      String membershipStatus =
          data['membershipStatus']?.toString() ?? 'Inactive';

      final validTillValue = data['validTill'];

      DateTime? validTill;

      if (validTillValue is Timestamp) {
        validTill = validTillValue.toDate();
      }

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

      // --------------------------------------------------
      // RULE 1:
      // Inactive membership must not have Valid Till.
      // --------------------------------------------------
      if (membershipStatus == 'Inactive') {
        if (validTillValue != null) {
          await studentRef.update({
            'validTill': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return {...data, 'membershipStatus': 'Inactive', 'validTill': null};
      }

      // --------------------------------------------------
      // RULE 2:
      // Active membership without Valid Till
      // is treated as Inactive.
      // --------------------------------------------------
      if (membershipStatus == 'Active' && validTill == null) {
        await studentRef.update({
          'membershipStatus': 'Inactive',
          'validTill': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return {...data, 'membershipStatus': 'Inactive', 'validTill': null};
      }

      // --------------------------------------------------
      // RULE 3:
      // Active membership whose Valid Till has passed
      // becomes Inactive automatically.
      // --------------------------------------------------
      if (membershipStatus == 'Active' && validTill != null) {
        final validTillDate = DateTime(
          validTill.year,
          validTill.month,
          validTill.day,
        );

        if (validTillDate.isBefore(today)) {
          await studentRef.update({
            'membershipStatus': 'Inactive',
            'validTill': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return {...data, 'membershipStatus': 'Inactive', 'validTill': null};
        }
      }

      // --------------------------------------------------
      // RULE 4:
      // Active + today/future Valid Till = Active.
      // --------------------------------------------------
      return {...data, 'membershipStatus': 'Active', 'validTill': validTill};
    } catch (e) {
      // Do not crash the app if membership checking fails.
      return null;
    }
  }

  /// Checks membership for multiple students.
  ///
  /// Useful for Admin Student Management screens.
  static Future<void> checkMultipleStudents(List<String> libraryIds) async {
    for (final libraryId in libraryIds) {
      if (libraryId.trim().isEmpty) {
        continue;
      }

      await checkAndUpdateMembership(libraryId.trim());
    }
  }
}
