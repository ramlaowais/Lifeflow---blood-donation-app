import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class DonationCentersPage extends StatefulWidget {
  const DonationCentersPage({Key? key}) : super(key: key);

  @override
  State<DonationCentersPage> createState() => _DonationCentersPageState();
}

class _DonationCentersPageState extends State<DonationCentersPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Position? _currentPosition;
  List<Map<String, dynamic>> _donationCenters = [];
  String _locationError = '';
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    // Create fade-in animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    // Create slide-up animation
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _loadDonationCenters();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDonationCenters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current location
      await _getCurrentLocation();

      // This would be replaced with actual data from Firestore
      // For now, we're using mock data with coordinates
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
          center['distance'] = (distanceInMeters / 1000).toStringAsFixed(1);
        }

        // Sort centers by distance
        centers.sort((a, b) {
          double distA = double.parse(a['distance']);
          double distB = double.parse(b['distance']);
          return distA.compareTo(distB);
        });
        
        // Get all centers, not just the nearest one
        if (centers.isNotEmpty) {
          setState(() {
            _donationCenters = centers;
            _isLoading = false;
          });
          
          // Start animations when data is loaded
          _animationController.reset();
          _animationController.forward();
        } else {
          setState(() {
            _locationError = 'No donation centers found.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _locationError = 'Unable to determine your location.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading donation centers: $e');
      setState(() {
        _isLoading = false;
        _locationError = 'Unable to determine your location.';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled. Please enable location services.';
      });
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied. Please allow location access.';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError = 'Location permissions are permanently denied. Please enable in settings.';
      });
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
      setState(() {
        _locationError = 'Error determining your location.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Donation Centers'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDonationCenters,
            tooltip: 'Refresh location',
          ),
        ],
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated loading indicator
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(seconds: 1),
                  builder: (context, value, child) {
                    return Column(
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            color: Colors.red,
                            value: null, // Indeterminate
                            strokeWidth: 5,
                          ),
                        ),
                        SizedBox(height: 24),
                        Opacity(
                          opacity: value,
                          child: Text(
                            'Finding donation centers...',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          )
        : _donationCenters.isEmpty
            ? Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _locationError.isEmpty 
                                  ? 'No donation centers found nearby.' 
                                  : _locationError,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadDonationCenters,
                              icon: Icon(Icons.refresh),
                              label: Text('Try Again'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animated title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Donation Centers Near You',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Based on your current location',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    // List of donation centers
                    ...List.generate(_donationCenters.length, (index) {
                      final center = _donationCenters[index];
                      // Staggered animation delay based on index
                      final delay = index * 0.1;
                      
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 500),
                        curve: Curves.easeOut,
                        // Add delay based on index for staggered effect
                        builder: (context, opacity, child) {
                          return Opacity(
                            opacity: opacity,
                            child: TweenAnimationBuilder<Offset>(
                              tween: Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero),
                              duration: Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              builder: (context, offset, child) {
                                return Transform.translate(
                                  offset: Offset(0, offset.dy * 50),
                                  child: child,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
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
                                              child: Icon(
                                                Icons.local_hospital,
                                                color: Colors.red,
                                                size: 28,
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    center['name'],
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
                                                          center['location'],
                                                          style: TextStyle(
                                                            color: Colors.grey.shade600,
                                                          ),
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
                                                    '${center['distance']} km',
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
                                                      Icon(
                                                        Icons.star,
                                                        size: 18,
                                                        color: Colors.amber,
                                                      ),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        center['rating'].toString(),
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
                                        SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Hours',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    center['openHours'],
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
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
                                                    'Phone',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    center['phone'],
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
    );
  }
}