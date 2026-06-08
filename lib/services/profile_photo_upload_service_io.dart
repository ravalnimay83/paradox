import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';

Future<void> uploadCroppedProfilePhotoImpl(Reference storageRef, CroppedFile croppedFile) {
  return storageRef.putFile(
    File(croppedFile.path),
    SettableMetadata(contentType: 'image/jpeg'),
  );
}
