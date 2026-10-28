import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  AuthService() {
    _auth.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    if (_user != null) {
      if (displayName != null) await _user!.updateDisplayName(displayName);
      if (photoURL != null) await _user!.updatePhotoURL(photoURL);
      // Wait for Firebase to propagate internally, then manually update local state and notify
      await _user!.reload();
      _user = _auth.currentUser;
      notifyListeners();
    }
  }

}
