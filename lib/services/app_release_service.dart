import 'package:cloud_firestore/cloud_firestore.dart';

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.notes,
    required this.isMandatory,
    required this.releasedAt,
  });

  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String notes;
  final bool isMandatory;
  final DateTime? releasedAt;

  bool isNewerThan(int currentVersionCode) => versionCode > currentVersionCode;

  factory AppReleaseInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppReleaseInfo(
      versionName: (data['versionName'] as String? ?? '').trim(),
      versionCode: (data['versionCode'] as num?)?.toInt() ?? 0,
      downloadUrl: (data['downloadUrl'] as String? ?? '').trim(),
      notes: (data['notes'] as String? ?? '').trim(),
      isMandatory: data['isMandatory'] as bool? ?? false,
      releasedAt: (data['releasedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AppReleaseService {
  AppReleaseService._();

  static const String _collection = 'app_releases';
  static const String _androidDoc = 'android_latest';

  static Stream<AppReleaseInfo?> watchAndroidLatest() {
    return FirebaseFirestore.instance.collection(_collection).doc(_androidDoc).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      final release = AppReleaseInfo.fromDoc(doc);
      if (release.downloadUrl.isEmpty) {
        return null;
      }
      return release;
    });
  }
}
