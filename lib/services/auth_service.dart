import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 15));

    final user = credential.user;
    if (user != null) {
      try {
        final userRef = _firestore.collection('users').doc(user.uid);
        final existing = await userRef.get();
        await userRef.set({
          'name': user.displayName ?? existing.data()?['name'] ?? '',
          'email': user.email ?? email,
          'role': existing.data()?['role'] ?? 'user',
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error) {
        debugPrint('Optional users write skipped: $error');
      }
    }

    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}
