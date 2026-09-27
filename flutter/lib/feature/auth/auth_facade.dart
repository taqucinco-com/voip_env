// https://pub.dev/packages/google_sign_in (v7 API)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class AuthorizationFacade {
  Future<UserCredential?> signInWithGoogle();
  Future<void> signOut();
  Future<String?> getIdToken();
  Future<void> deleteAccount();
}

class AuthorizationFacadeImpl implements AuthorizationFacade {
  @override
  Future<String?> getIdToken() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) print('No user is currently signed in.');
        return null;
      }
      final String? idToken = await user.getIdToken();
      if (kDebugMode) print('User idToken successfully retrieved! $idToken');
      return idToken;
    } catch (e) {
      if (kDebugMode) print('Failed to get idToken: $e');
      return null;
    }
  }

  @override
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // google_sign_in v7からGoogleSignIn.instanceはinitialize()呼び出し後に使う必要がある。
      // main()で一度だけinitialize()している前提。
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (kDebugMode) print('Google sign-in failed: ${e.code} ${e.description}');
      return null;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('Failed with error code: ${e.code}');
      if (kDebugMode) print(e.message);
      return null;
    } catch (e) {
      if (kDebugMode) print(e);
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) print('No user is currently signed in.');
        return;
      }
      await user.delete();
      if (kDebugMode) print('User successfully deleted!');
    } catch (e) {
      if (kDebugMode) print('Failed to delete user: $e');
    }
  }
}
