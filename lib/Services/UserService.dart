import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service class to handle backend operations for the User (Blind/Deaf) role.
/// This includes user data management, request creation, and history tracking.
class UserService {
  // Firebase instances for Auth and Firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getter to retrieve the currently logged-in user
  User? get currentUser => _auth.currentUser;

  /// Fetches the current user's profile data from Firestore.
  /// Returns a Map of user data or null if not found.
  Future<Map<String, dynamic>?> loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Fetch the document from the 'users' collection matching the user's UID
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data();
        }
      } catch (e) {
        debugPrint('Failed to load user data: $e');
        rethrow; // Re-throw error to be handled by the UI
      }
    }
    return null;
  }

  /// Fetches the history of requests made by the current user.
  /// Returns a list of request data maps.
  Future<List<Map<String, dynamic>>> loadUserRequests() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Query requests where 'userId' matches the current user's ID
        final querySnapshot = await _firestore
            .collection('requests')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .get();

        // Map the documents to a list of data objects
        return querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'status': data['status'] ?? 'Unknown',
            'volunteerName': data['volunteerName'] ?? 'Unknown',
            'volunteerPhoto': data['volunteerPhotoUrl'],
            'contact': data['volunteerContact'] ?? '',
            'timestamp': data['createdAt']?.toDate() ?? DateTime.now(),
          };
        }).toList();
      } catch (e) {
        debugPrint('Failed to load user requests: $e');
        rethrow;
      }
    }
    return [];
  }

  /// Creates a new assistance request in Firestore.
  /// Returns the ID of the newly created request document.
  Future<String> createRequest({
    required String userName,
    required String userType,
    required String channelId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    debugPrint("Creating request for user: ${user.uid}");
    // Add a new document to the 'requests' collection
    final docRef = await _firestore.collection('requests').add({
      'userId': user.uid,
      'userName': userName,
      'userType': userType,
      'userPhoto': null, // TODO: Add user photo if available
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'channelId': channelId,
    });

    debugPrint("Request created successfully");
    return docRef.id;
  }

  /// Updates a request in Firestore to mark it as 'completed'.
  Future<void> completeRequest(String requestId) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Signs out the user and clears local preferences.
  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userType');
  }
}
