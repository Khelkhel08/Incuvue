import 'package:cloud_firestore/cloud_firestore.dart';

class ContactService {
  final FirebaseFirestore _firestore;

  ContactService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> submitRequest({
    required String email,
    required String concernType,
    required String description,
  }) async {
    final doc = _firestore.collection('contact_requests').doc();
    await doc.set({
      'requestId': doc.id,
      'email': email,
      'concernType': concernType,
      'description': description,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
