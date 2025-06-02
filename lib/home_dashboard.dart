import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'donation_history_page.dart';
import 'my_requests_page.dart';
import 'donation_centers.dart'; // Added import for the donation centers page

class HomeDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeDashboard({Key? key, this.userData = const {}}) : super(key: key);

  @override
  HomeDashboardState createState() => HomeDashboardState();
}

class HomeDashboardState extends State<HomeDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
    bool _isLoadingCenters = false;
  List<Map<String, dynamic>> _nearbyRequests = [];
  List<Map<String, dynamic>> _myRequests = [];
  List<Map<String, dynamic>> _donationCenters = [];
  String _selectedFilter = 'All';
  late Animation<double> _fadeAnimation;
  Position? _currentPosition;
  String _locationError = '';

  // Public method to show request details dialog
  void showRequestDetailsDialog(Map<String, dynamic> request) {
    _showRequestDetailsDialog(request);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
    _loadNearbyRequests();
    _loadMyRequests();
    _loadDonationCenters();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  // Private implementation of the request details dialog
  void _showRequestDetailsDialog(Map<String, dynamic> request) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Fetch requester details from Firestore
      final requesterId = request['requester_id'];
      final requesterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(requesterId)
          .get();
      
      if (!requesterDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Requester details not found')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final requesterData = requesterDoc.data() as Map<String, dynamic>;
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Request Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailSection(
                  title: 'Patient Information',
                  details: [
                    {'label': 'Name', 'value': request['patient_name'] ?? 'Unknown'},
                    {'label': 'Age', 'value': request['age'] != null ? '${request['age']} years' : 'Unknown'},
                    {'label': 'Blood Type', 'value': request['blood_type'] ?? 'Unknown'},
                    {'label': 'Urgency', 'value': request['urgency'] ?? 'Medium'},
                  ],
                ),
                SizedBox(height: 16),
                _buildDetailSection(
                  title: 'Requester Information',
                  details: [
                    {'label': 'Name', 'value': requesterData['name'] ?? 'Unknown'},
                    {'label': 'Phone', 'value': requesterData['phone'] ?? 'Not provided'},
                    {'label': 'Email', 'value': requesterData['email'] ?? 'Not provided'},
                  ],
                ),
                SizedBox(height: 16),
                _buildDetailSection(
                  title: 'Location Details',
                  details: [
                    {'label': 'Hospital', 'value': request['location'] ?? 'Unknown'},
                    {'label': 'Distance', 'value': '${(request['distance'] as double).toStringAsFixed(1)} km'},
                    {'label': 'Posted', 'value': _getTimeAgo(request['request_date'])},
                  ],
                ),
                SizedBox(height: 16),
                if (request['notes'] != null && request['notes'].toString().isNotEmpty)
                  _buildDetailSection(
                    title: 'Additional Notes',
                    details: [
                      {'label': '', 'value': request['notes']},
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showRespondDialog(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: Text('Respond'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error fetching requester details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDetailSection({
    required String title,
    required List<Map<String, String>> details,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.red,
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            children:
                details.map((detail) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (detail['label']!.isNotEmpty) ...[
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${detail['label']}:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            detail['value']!,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _loadMyRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Simple query without orderBy (no index required)
      final snapshot =
          await _firestore
              .collection('blood_requests')
              .where('requester_id', isEqualTo: user.uid)
              .where('is_active', isEqualTo: true)
              .get();

      // Sort the results client-side
      final sortedDocs =
          snapshot.docs.toList()..sort((a, b) {
            final aDate = a['request_date'] as Timestamp;
            final bDate = b['request_date'] as Timestamp;
            return bDate.compareTo(aDate); // descending order (newest first)
          });

      // Take only the first 3 after sorting
      final limitedDocs =
          sortedDocs.length > 3 ? sortedDocs.sublist(0, 3) : sortedDocs;

      setState(() {
        _myRequests =
            limitedDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            }).toList();
      });
    } catch (e) {
      print('Error loading my requests: $e');
    }
  }

  Future<void> _loadNearbyRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request location permission
      await _getCurrentLocation();

      // Simple query without orderBy (no index required)
      Query query = _firestore
          .collection('blood_requests')
          .where('is_active', isEqualTo: true);

      // Apply blood type filter if not "All"
      if (_selectedFilter != 'All') {
        query = query.where('blood_type', isEqualTo: _selectedFilter);
      }

      final snapshot = await query.get();

      final requests =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;

            // Calculate distance if we have user location
            if (_currentPosition != null) {
              // In a real app, you would store lat/lng with each request
              // For now, we'll simulate distance based on the document ID
              data['distance'] = (doc.id.hashCode % 10 + 1).toDouble();
            } else {
              data['distance'] = double.infinity;
            }

            return data;
          }).toList();

      // Sort by date (newest first) and then by distance
      requests.sort((a, b) {
        // First sort by date
        final aDate = a['request_date'] as Timestamp;
        final bDate = b['request_date'] as Timestamp;
        final dateComparison = bDate.compareTo(aDate);

        // If dates are the same, sort by distance
        if (dateComparison == 0) {
          return (a['distance'] as double).compareTo(b['distance'] as double);
        }

        return dateComparison;
      });

      // Limit to 10 results after sorting
      final limitedRequests =
          requests.length > 10 ? requests.sublist(0, 10) : requests;

      setState(() {
        _nearbyRequests = limitedRequests;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading blood requests: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading nearby requests: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission permanently denied.'),
        ),
      );
      return;
    }

    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _loadDonationCenters() async {
    setState(() {
      _isLoadingCenters = true;
    });

    try {
      // Get current location if not already available
      if (_currentPosition == null) {
        await _getCurrentLocation();
      }

      // Use the same data as in DonationCentersPage
      final List<Map<String, dynamic>> centers = [
        {
          'name': 'Red Crescent Blood Bank',
          'location': 'Blue Area, Islamabad',
          'latitude': 33.7294,
          'longitude': 73.0931,
          'rating': 4.5,
          'openHours': '9:00 AM - 5:00 PM',
          'phone': '+92-51-9250740',
        },
        {
          'name': 'Shifa International Hospital',
          'location': 'H-8/4, Islamabad',
          'latitude': 33.6938,
          'longitude': 73.0652,
          'rating': 4.8,
          'openHours': '24 hours',
          'phone': '+92-51-8464646',
        },
        {
          'name': 'PIMS Blood Center',
          'location': 'G-8/3, Islamabad',
          'latitude': 33.6992,
          'longitude': 73.0428,
          'rating': 4.2,
          'openHours': '8:00 AM - 8:00 PM',
          'phone': '+92-51-9261170',
        },
        {
          'name': 'Poly Clinic Blood Bank',
          'location': 'G-6/2, Islamabad',
          'latitude': 33.7278,
          'longitude': 73.0812,
          'rating': 4.0,
          'openHours': '9:00 AM - 4:00 PM',
          'phone': '+92-51-9218300',
        },
        {
          'name': 'Holy Family Hospital',
          'location': 'Satellite Town, Rawalpindi',
          'latitude': 33.6518,
          'longitude': 73.0587,
          'rating': 4.3,
          'openHours': '24 hours',
          'phone': '+92-51-9290319',
        },
      ];

      // Calculate distance for each center if we have user's location
      if (_currentPosition != null) {
        for (var center in centers) {
          double distanceInMeters = await Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            center['latitude'],
            center['longitude'],
          );

          // Convert to kilometers and round to 1 decimal place
          center['distance'] =
              (distanceInMeters / 1000).toStringAsFixed(1) + ' km';
        }

        // Sort centers by distance
        centers.sort((a, b) {
          double distA = double.parse(
            a['distance'].toString().replaceAll(' km', ''),
          );
          double distB = double.parse(
            b['distance'].toString().replaceAll(' km', ''),
          );
          return distA.compareTo(distB);
        });
      }

      setState(() {
        _donationCenters = centers;
        _isLoadingCenters = false;
      });
    } catch (e) {
      print('Error loading donation centers: $e');
      setState(() {
        _isLoadingCenters = false;
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Filter Blood Requests'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('All Blood Types'),
                  value: 'All',
                  groupValue: _selectedFilter,
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                    });
                    Navigator.pop(context);
                    _loadNearbyRequests();
                  },
                ),
                ...['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].map((
                  type,
                ) {
                  return RadioListTile<String>(
                    title: Text(type),
                    value: type,
                    groupValue: _selectedFilter,
                    onChanged: (value) {
                      setState(() {
                        _selectedFilter = value!;
                      });
                      Navigator.pop(context);
                      _loadNearbyRequests();
                    },
                  );
                }).toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showRespondDialog(Map<String, dynamic> request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Respond to Blood Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to respond to a blood request for:',
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient: ${request['patient_name']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text('Blood Type: ${request['blood_type']}'),
                  SizedBox(height: 4),
                  Text('Location: ${request['location']}'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'By responding, you agree to be contacted by the requester for donation coordination.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToRequest(request);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _respondToRequest(Map<String, dynamic> request) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get current user data
      final userData = await _firestore.collection('users').doc(user.uid).get();

      // Create a response document
      await _firestore.collection('blood_responses').add({
        'request_id': request['id'],
        'responder_id': user.uid,
        'responder_name': userData.get('name'),
        'responder_phone': userData.get('phone'),
        'responder_blood_group': userData.get('blood_group'),
        'response_date': Timestamp.now(),
        'status': 'pending', // pending, accepted, rejected
      });

      // Add notification for the requester
      await _firestore.collection('notifications').add({
        'user_id': request['requester_id'],
        'title': 'Response to Blood Request',
        'body':
            '${userData.get('name')} has responded to your blood request for ${request['patient_name']}',
        'type': 'blood_response',
        'read': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your response has been sent to the requester'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error responding to request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadNearbyRequests();
            await _loadMyRequests();
            await _loadDonationCenters();
          },
          // Use a LayoutBuilder to get the available height
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreeting(),
                          const SizedBox(height: 24),
                          _buildUserStats(),
                          const SizedBox(height: 32),

                          // My Requests Section (New)
                          if (_myRequests.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'My Active Requests',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MyRequestsPage(),
                                      ),
                                    ).then((_) => _loadMyRequests());
                                  },
                                  icon: Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  label: Text(
                                    'View All',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildMyRequestsList(),
                            const SizedBox(height: 24),
                          ],

                          // Wrap the nearby requests in a container with fixed height
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Blood Requests Nearby',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showFilterDialog,
                                    icon: Icon(
                                      Icons.filter_list,
                                      size: 18,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    label: Text(
                                      _selectedFilter == 'All'
                                          ? 'Filter'
                                          : _selectedFilter,
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _isLoading
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : _nearbyRequests.isEmpty
                                  ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        children: [
                                          const Icon(
                                            Icons.search_off,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No blood requests found',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  // Limit the height of the nearby requests section
                                  : Container(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                          0.4,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children:
                                            _nearbyRequests
                                                .where(
                                                  (request) =>
                                                      _selectedFilter ==
                                                          'All' ||
                                                      request['blood_type'] ==
                                                          _selectedFilter,
                                                )
                                                .map(
                                                  (request) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 12.0,
                                                        ),
                                                    child: _buildRequestCard(
                                                      request: request,
                                                      patientName:
                                                          request['patient_name'] ??
                                                          'Unknown',
                                                      age:
                                                          int.tryParse(
                                                            request['age'] ??
                                                                '0',
                                                          ) ??
                                                          0,
                                                      bloodType:
                                                          request['blood_type'] ??
                                                          'Unknown',
                                                      distance:
                                                          '${(request['distance'] as double).toStringAsFixed(1)} km',
                                                      hospital:
                                                          request['location'] ??
                                                          'Unknown',
                                                      urgency:
                                                          request['urgency'] ??
                                                          'Medium',
                                                      timeAgo: _getTimeAgo(
                                                        request['request_date'],
                                                      ),
                                                      requestId: request['id'],
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                      ),
                                    ),
                                  ),
                              const SizedBox(height: 8),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildDonationCenters(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    String greeting = 'Good morning';

    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17) {
      greeting = 'Good evening';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, ${widget.userData['name'] ?? 'User'}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to save lives today?',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Statistics',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem(
                'Blood Type',
                widget.userData['blood_group'] ?? 'Unknown',
                Icons.bloodtype,
              ),
              _buildStatItem('Donations', '3', Icons.volunteer_activism),
              _buildStatItem('Lives Saved', '9', Icons.favorite),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to donation history
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DonationHistoryPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, color: Colors.red),
                  label: const Text(
                    'Donation History',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyRequestsPage()),
                    ).then((_) => _loadMyRequests());
                  },
                  icon: const Icon(Icons.list_alt, color: Colors.white),
                  label: const Text(
                    'My Requests',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRequestsList() {
    return Column(
      children:
          _myRequests.map((request) {
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyRequestsPage()),
                    ).then((_) => _loadMyRequests());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            request['blood_type'] ?? 'A+',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request['patient_name'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Urgency: ${request['urgency']} • ${_getTimeAgo(request['request_date'])}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    final now = DateTime.now();
    final requestTime = timestamp.toDate();
    final difference = now.difference(requestTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildRequestCard({
    required Map<String, dynamic> request,
    required String patientName,
    required int age,
    required String bloodType,
    required String distance,
    required String hospital,
    required String urgency,
    required String timeAgo,
    required String requestId,
  }) {
    Color urgencyColor =
        urgency == 'High'
            ? Colors.red
            : urgency == 'Medium'
            ? Colors.orange
            : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Show details when tapping the card
            _showRequestDetailsDialog(request);
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        bloodType,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: urgencyColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$urgency urgency',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: urgencyColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$patientName, $age years old',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$hospital ($distance away)',
                        style: TextStyle(color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Respond to request
                          _showRespondDialog(request);
                        },
                        icon: const Icon(Icons.bloodtype),
                        label: const Text('Respond'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // View details - now connected to the function
                        _showRequestDetailsDialog(request);
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
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
            _locationError.isNotEmpty
                ? _locationError
                : 'No blood requests found nearby',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadNearbyRequests,
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCenters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Donation Centers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Show loading indicator while centers are loading
        _isLoadingCenters
            ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
            // Show the first donation center if available
            : _donationCenters.isNotEmpty
            ? _buildDonationCenterCard(
              name: _donationCenters[0]['name'] ?? 'Unknown',
              distance: _donationCenters[0]['distance'] ?? 'Unknown',
              address:
                  _donationCenters[0]['location'] ??
                  'Unknown', // Using 'location' instead of 'address'
              rating: _donationCenters[0]['rating'] ?? 0.0,
            )
            : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  'No donation centers found nearby',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: () {
              // Navigate to donation centers page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DonationCentersPage()),
              );
            },
            icon: const Icon(Icons.list, color: Colors.red),
            label: const Text(
              'View All Centers',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDonationCenterCard({
    required String name,
    required String distance,
    required String
    address, // This parameter is still called 'address' in the method signature
    required double rating,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_hospital, color: Colors.red, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address, // Using the address parameter here
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      distance,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 18, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          rating.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}