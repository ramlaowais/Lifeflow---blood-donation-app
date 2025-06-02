import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final Map<String, List<String>> _compatibilityChart = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'AB-': ['A-', 'B-', 'AB-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
  };

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> notifyCompatibleDonors(
      String bloodType, String location, String patientName,
      [String urgency = 'Medium', String? requestId]) async {
    try {
      List<String> compatibleDonors = _compatibilityChart[bloodType] ?? [];
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      QuerySnapshot userSnapshot = await _firestore
          .collection('users')
          .where('blood_group', whereIn: compatibleDonors)
          .get();

      for (var doc in userSnapshot.docs) {
        String userId = doc.id;
        if (userId == currentUser.uid) continue;

        await _firestore.collection('notifications').add({
          'user_id': userId,
          'title': urgency == 'High' ? 'URGENT Blood Request' : 'Blood Request',
          'body':
              'Patient $patientName ${urgency == 'High' ? 'urgently ' : ''}needs ${bloodType} blood donation near $location',
          'type': 'blood_request',
          'urgency': urgency,
          'request_id': requestId,
          'read': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      await _showLocalNotification(
        urgency == 'High' ? 'URGENT Blood Request Sent' : 'Blood Request Sent',
        'Your request has been sent to ${userSnapshot.docs.length} potential donors',
      );
    } catch (e) {
      print('Error sending notifications: $e');
    }
  }

  static Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'blood_donation_channel',
      'Blood Donation Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  static Stream<List<QueryDocumentSnapshot>> getUserNotifications() async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    await for (var snapshot in _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: user.uid)
        .snapshots()) {
      List<QueryDocumentSnapshot> docs = snapshot.docs;
      docs.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;
        return bTime?.compareTo(aTime ?? Timestamp.now()) ?? 0;
      });
      yield docs;
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'read': true});
  }

  static Future<List<Map<String, dynamic>>> getNearbyBloodRequests() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final userBloodType = userData['blood_group'] as String?;

      if (userBloodType == null) return [];

      // Determine compatible recipients based on donor type
      List<String> compatibleRecipients = [];
      _compatibilityChart.forEach((recipient, donors) {
        if (donors.contains(userBloodType)) {
          compatibleRecipients.add(recipient);
        }
      });

      // 🟡 Avoids compound index by filtering client-side
      final snapshot = await _firestore
          .collection('blood_requests')
          .where('is_active', isEqualTo: true) // Only one filter
          .get();

      List<QueryDocumentSnapshot> docs = snapshot.docs
          .where((doc) => compatibleRecipients.contains(doc['blood_type']))
          .toList();

      docs.sort((a, b) {
        final aTime = a['request_date'] as Timestamp?;
        final bTime = b['request_date'] as Timestamp?;
        return bTime?.compareTo(aTime ?? Timestamp.now()) ?? 0;
      });

      final limitedDocs = docs.take(10).toList();

      return limitedDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting nearby blood requests: $e');
      return [];
    }
  }
}