import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({Key? key}) : super(key: key);

  @override
  _MyRequestsPageState createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<DocumentSnapshot> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
  setState(() {
    _isLoading = true;
  });

  try {
    final user = _auth.currentUser;
    if (user == null) return;

    // Simple query without orderBy (no index required)
    final snapshot = await _firestore
        .collection('blood_requests')
        .where('requester_id', isEqualTo: user.uid)
        .get();

    // Sort the results client-side
    final sortedDocs = snapshot.docs.toList()
      ..sort((a, b) {
        final aDate = a['request_date'] as Timestamp;
        final bDate = b['request_date'] as Timestamp;
        return bDate.compareTo(aDate); // descending order (newest first)
      });

    setState(() {
      _requests = sortedDocs;
      _isLoading = false;
    });
  } catch (e) {
    print('Error loading requests: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading your requests. Please try again.')),
    );
    setState(() {
      _isLoading = false;
    });
  }
}

  Future<void> _toggleRequestStatus(String requestId, bool currentStatus) async {
    try {
      await _firestore.collection('blood_requests').doc(requestId).update({
        'is_active': !currentStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentStatus 
                ? 'Request marked as resolved' 
                : 'Request reactivated'
          ),
          backgroundColor: currentStatus ? Colors.green : Colors.blue,
        ),
      );

      // Refresh the list
      _loadRequests();
    } catch (e) {
      print('Error updating request status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating request status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Blood Requests'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadRequests,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? _buildEmptyState()
              : _buildRequestsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bloodtype_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No blood requests yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to request blood page
            },
            icon: Icon(Icons.add),
            label: Text('Create New Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        final data = request.data() as Map<String, dynamic>;
        final requestDate = data['request_date'] as Timestamp?;
        final formattedDate = requestDate != null
            ? DateFormat('MMM d, yyyy').format(requestDate.toDate())
            : 'Unknown date';
        final isActive = data['is_active'] ?? true;

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActive ? Colors.red.shade200 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.red.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        data['blood_type'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.red : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Patient: ${data['patient_name'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('Location: ${data['location'] ?? 'Unknown'}'),
                SizedBox(height: 4),
                Text('Urgency: ${data['urgency'] ?? 'Medium'}'),
                if (data['notes'] != null && data['notes'].toString().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Notes: ${data['notes']}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isActive ? 'Status: Active' : 'Status: Resolved',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                    Switch(
                      value: isActive,
                      activeColor: Colors.red,
                      onChanged: (value) {
                        _toggleRequestStatus(request.id, isActive);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}