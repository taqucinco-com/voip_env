# voip_env

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Auth

- Firebase AuthでClientの認証を行う

```sh
brew update && brew install --cask gcloud-cli
dart pub global activate flutterfire_cli
gcloud auth login
gcloud projects list
gcloud config set project voip-env
gcloud config get-value project
firebase login
firebase projects:list
flutter pub add firebase_core
fvm dart pub global run flutterfire_cli:flutterfire configure --android-package-name=com.taqucinco.voip_env --ios-bundle-id={app_id} --platforms=android,ios,web --project=voip-env --overwrite-firebase-options
```

firebase側でproject設定ができていれば上記のコマンドでgoogle servicesを取得できる。
以下のファイルもこのコマンドで認証されているユーザーが取得できるため.gitignoreとして扱う。

- firebase.json
- lib/firebase_options.dart

### Android

debug.keystoreのSHA-1は以下のコマンドで表示する。

```sh
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## VOIP

VOIPのClient側として実装
