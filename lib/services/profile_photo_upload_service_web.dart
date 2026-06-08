import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_cropper/image_cropper.dart';

Future<void> uploadCroppedProfilePhotoImpl(Reference storageRef, CroppedFile croppedFile) async {
  final bytes = await croppedFile.readAsBytes();
  await storageRef.putData(
    bytes,
    SettableMetadata(contentType: 'image/jpeg'),
  );
}
