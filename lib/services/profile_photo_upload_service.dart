import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

Future<TaskSnapshot> uploadCroppedProfilePhoto(Reference storageRef, Uint8List croppedBytes) {
    return storageRef.putData(
        croppedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
    );
}
