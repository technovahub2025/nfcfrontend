# nfc

A new Flutter project.

## Run in Chrome

From PowerShell in the project directory:

```powershell
.\run_web.ps1
```

The launcher puts Flutter's temporary compilation files in `.build-temp` on
the project's drive, avoiding a full system drive. It restores the original
temporary directory settings when Flutter exits.

For Edge, use `.\run_web.ps1 -Device edge`.

## Browser API access (CORS)

The profile API must allow the Flutter web application's origin. Its OPTIONS
response currently allows the request methods and headers but does not return
`Access-Control-Allow-Origin` for localhost, so browsers block profile saves.
This configuration belongs in the backend, before its API routes.

In `D:\nfcprofilebackend-1\server.js`, include the exact local origin in the existing
CORS middleware:

```js
app.use(cors({
  origin: [
    'https://www.technovahub.in',
    'http://localhost:3000',
    'http://localhost:5173',
    'http://localhost:64165',
  ],
  credentials: true,
}));
```

The backend change must be deployed before it affects the live API. The launcher
uses port 64165 so its origin matches this configuration:

```powershell
.\run_web.ps1
```

Both OPTIONS and the actual API responses must include the allowed origin.
Adding CORS headers to Flutter requests cannot grant browser access.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
