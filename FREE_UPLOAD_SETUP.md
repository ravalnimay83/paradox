# Free Upload Setup (Cloudinary)

This project is configured to upload images/videos to Cloudinary (free tier), then save post metadata in Firestore.

## 1. Create free Cloudinary account

- Sign up: https://cloudinary.com/users/register_free
- Console: https://console.cloudinary.com/

## 2. Create unsigned upload preset

1. Open Cloudinary Console
2. Settings -> Upload
3. Scroll to "Upload presets"
4. Click "Add upload preset"
5. Set:
   - Signing Mode: `Unsigned`
   - Folder (optional): `paradox_posts`
6. Save and copy the preset name

## 3. Get Cloud name

- Cloud name is shown on Cloudinary dashboard.

## 4. Run app with dart-define values

Required value:
- `CLOUDINARY_UPLOAD_PRESET`

Optional override:
- `CLOUDINARY_CLOUD_NAME` (defaults to `dq2mfprl4` in this app)

```powershell
Start-Process -FilePath 'D:\Softwares\MyFlutterSoftware\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat' -ArgumentList @(
  'run',
  '--dart-define=CLOUDINARY_UPLOAD_PRESET=YOUR_UNSIGNED_PRESET'
) -NoNewWindow -Wait
```

If you want to override cloud name:

```powershell
Start-Process -FilePath 'D:\Softwares\MyFlutterSoftware\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat' -ArgumentList @(
  'run',
  '--dart-define=CLOUDINARY_CLOUD_NAME=YOUR_CLOUD_NAME',
  '--dart-define=CLOUDINARY_UPLOAD_PRESET=YOUR_UNSIGNED_PRESET'
) -NoNewWindow -Wait
```

## 5. In app

1. Sign in
2. Open Create Post
3. Pick image/video
4. Tap "Test Upload" (optional)
5. Add caption and tap "Upload"

## 6. Data flow

- Media file goes to Cloudinary URL
- Firestore `posts` stores:
  - ownerId
  - mediaUrl
  - mediaType
  - caption
  - createdAt

## Notes

- Firebase Storage plan upgrade is no longer required for media upload.
- Firestore is still used for metadata and app feed/profile data.
