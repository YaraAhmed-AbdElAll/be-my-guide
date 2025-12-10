import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service class to handle backend operations for the Volunteer role.
/// This includes user data management, notifications, and request handling.
class VolunteerService {
  // Firebase instances for Auth, Firestore, and Messaging
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

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

  /// Requests notification permissions and subscribes the user to the appropriate topic
  /// based on their role (volunteer or sign_language_expert).
  Future<void> setupNotifications(String type) async {
    // Request permission for alerts, badges, and sounds
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      // Subscribe to topics based on user type to receive relevant notifications
      if (type == 'volunteer') {
        await _messaging.subscribeToTopic('topic_volunteer');
        debugPrint('Subscribed to topic_volunteer');
      } else if (type == 'sign_language_expert') {
        await _messaging.subscribeToTopic('topic_sign_language_expert');
        debugPrint('Subscribed to topic_sign_language_expert');
      }
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  /// Returns a stream of pending requests filtered by the user's role.
  /// Volunteers see requests from 'blind' users.
  /// Sign Language Experts see requests from 'deaf' users.
  Stream<QuerySnapshot> getRequestsStream(String userType) {
    // Start with a query for all pending requests
    Query query = _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending');

    // Apply filtering based on the volunteer's expertise
    if (userType == 'volunteer') {
      query = query.where('userType', isEqualTo: 'blind');
    } else if (userType == 'sign_language_expert') {
      query = query.where('userType', isEqualTo: 'deaf');
    }

    // Return the stream ordered by creation time (newest first)
    return query.orderBy('createdAt', descending: true).snapshots();
  }

  /// Updates a request in Firestore to mark it as 'accepted'.
  /// Sets the volunteer's ID and name on the request document.
  Future<void> acceptRequestInFirestore(
    String requestId,
    String volunteerName,
  ) async {
    await _firestore.collection('requests').doc(requestId).update({
      'status': 'accepted',
      'volunteerId': _auth.currentUser?.uid,
      'volunteerName': volunteerName,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates a request in Firestore to mark it as 'completed'.
  Future<void> completeRequestInFirestore(String requestId) async {
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
