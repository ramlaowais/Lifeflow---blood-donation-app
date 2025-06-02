import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'my_requests_page.dart';

class AskBloodPage extends StatefulWidget {
  const AskBloodPage({super.key});

  @override
  State<AskBloodPage> createState() => _AskBloodPageState();
}

class _AskBloodPageState extends State<AskBloodPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedBloodType = 'A+';
  String _selectedUrgency = 'Medium';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  final List<String> _urgencyLevels = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();

    // Initialize notification service
    NotificationService.initialize();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
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

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        String fullAddress =
            '${place.name}, ${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';

        setState(() {
          _locationController.text = fullAddress;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You must be logged in to submit a request')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user data
      final userData =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      // Create the blood request
      DocumentReference requestRef = await FirebaseFirestore.instance
          .collection('blood_requests')
          .add({
            'patient_name': _nameController.text.trim(),
            'age': _ageController.text.trim(),
            'blood_type': _selectedBloodType,
            'urgency': _selectedUrgency,
            'location': _locationController.text.trim(),
            'notes': _notesController.text.trim(),
            'requester_id': user.uid,
            'requester_name': userData.get('name'),
            'requester_phone': userData.get('phone'),
            'request_date': Timestamp.now(),
            'is_active': true,
          });

      // Send notifications to compatible donors with urgency level and request ID
      await NotificationService.notifyCompatibleDonors(
        _selectedBloodType,
        _locationController.text.trim(),
        _nameController.text.trim(),
        _selectedUrgency,
        requestRef.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Blood request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Show dialog asking if user wants to view their requests
      _showRequestSubmittedDialog();

      _formKey.currentState!.reset();
      _nameController.clear();
      _ageController.clear();
      _locationController.clear();
      _notesController.clear();
      setState(() {
        _selectedBloodType = 'A+';
        _selectedUrgency = 'Medium';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showRequestSubmittedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Request Submitted'),
            content: Text(
              'Your blood request has been submitted successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyRequestsPage()),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('View My Requests'),
              ),
            ],
          ),
    );
  }

  void _navigateToMyRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MyRequestsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Request'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'My Requests',
            onPressed: _navigateToMyRequests,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          const Text(
                            'Submit a Blood Request',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Fill in the details to request blood donation',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Patient Name
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Patient Name",
                              hintText: "Enter patient's full name",
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator:
                                (value) =>
                                    value == null || value.isEmpty
                                        ? 'Required field'
                                        : null,
                          ),
                          const SizedBox(height: 16),

                          // Age & Blood Type Row
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  decoration: const InputDecoration(
                                    labelText: "Age",
                                    hintText: "Patient's age",
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator:
                                      (value) =>
                                          value == null || value.isEmpty
                                              ? 'Required'
                                              : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedBloodType,
                                  decoration: const InputDecoration(
                                    labelText: "Blood Type",
                                    prefixIcon: Icon(Icons.bloodtype),
                                  ),
                                  items:
                                      _bloodTypes
                                          .map(
                                            (type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedBloodType = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Urgency
                          DropdownButtonFormField<String>(
                            value: _selectedUrgency,
                            decoration: const InputDecoration(
                              labelText: "Urgency Level",
                              prefixIcon: Icon(Icons.priority_high),
                            ),
                            items:
                                _urgencyLevels
                                    .map(
                                      (level) => DropdownMenuItem(
                                        value: level,
                                        child: Text(level),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedUrgency = value!;
                              });
                            },
                          ),
                          if (_selectedUrgency == 'High')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'High urgency requests will send notifications to compatible donors',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

                          // Location with button
                          TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              labelText: "Hospital/Location",
                              hintText: "Enter hospital or location",
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getCurrentLocation,
                                tooltip: "Use current location",
                              ),
                            ),
                            validator:
                                (value) =>
                                    value == null || value.isEmpty
                                        ? 'Required field'
                                        : null,
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          TextFormField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: "Additional Notes",
                              hintText:
                                  "Enter any additional information (optional)",
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(bottom: 64),
                                child: Icon(Icons.note_alt_outlined),
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.bloodtype),
                              label: const Text("Submit Blood Request"),
                              onPressed: _submitRequest,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                          Text(
                            'Your request will be visible to nearby donors with matching blood type.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
        ),
      ),
    );
  }
}