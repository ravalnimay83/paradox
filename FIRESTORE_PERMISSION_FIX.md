# Firestore Permission Fix (Exact Steps)

## A) Fastest method (Firebase Console)

1. Open Firestore Rules:
   - https://console.firebase.google.com/project/paradox-9d854/firestore/rules
2. Replace all existing rules with the content from `firebase/firestore.rules`.
3. Click **Publish**.

## B) Command-line method (if Firebase CLI is installed)

Run from project root:

```powershell
Set-Location 'c:\Users\Nimay\StudioProjects\Paradox'
firebase login
firebase use paradox-9d854
firebase deploy --only firestore:rules
```

## C) Run app and test upload

```powershell
Start-Process -FilePath 'D:\Softwares\MyFlutterSoftware\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat' -ArgumentList @(
  'run',
  '--dart-define=CLOUDINARY_UPLOAD_PRESET=paradox_unsigned_upload'
) -NoNewWindow -Wait
```

In app:
1. Login
2. Open Create Post
3. Pick image/video
4. Tap Upload

## If still failing

Share the full SnackBar text and I will patch rules/code accordingly.
