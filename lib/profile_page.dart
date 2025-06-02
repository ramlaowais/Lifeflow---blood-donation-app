import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
// Removed share_plus import since it's not installed
import 'dart:io';
import 'login_page.dart';
import 'donation_history_page.dart';

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfilePage({Key? key, required this.userData}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _profileImageUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isDarkMode = false;
  List<Map<String, dynamic>> _donationHistory = [];
  Map<String, dynamic> _statistics = {
    'totalDonations': 0,
    'livesSaved': 0,
    'lastDonation': null,
    'nextEligibleDate': null,
  };

  // Controllers for editing profile
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  String _selectedBloodGroup = 'A+';
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
    _profileImageUrl = widget.userData['profile_image'];
    _selectedBloodGroup = widget.userData['blood_group'] ?? 'A+';

    // Initialize controllers with user data
    _nameController.text = widget.userData['name'] ?? '';
    _phoneController.text = widget.userData['phone'] ?? '';
    _addressController.text = widget.userData['address'] ?? '';

    _loadDonationHistory();
    _calculateStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _showAchievementsDialog() {
    // Define some achievements
    final List<Map<String, dynamic>> achievements = [
      {
        'title': 'First Time Donor',
        'description': 'Completed your first blood donation',
        'icon': Icons.bloodtype,
        'color': Colors.red,
        'unlocked': true,
        'progress': 1.0,
      },
      {
        'title': 'Regular Donor',
        'description': 'Donated blood 3 times',
        'icon': Icons.favorite,
        'color': Colors.pink,
        'unlocked': true,
        'progress': 1.0,
      },
      {
        'title': 'Life Saver',
        'description': 'Your donations have helped save 9 lives',
        'icon': Icons.volunteer_activism,
        'color': Colors.orange,
        'unlocked': true,
        'progress': 1.0,
      },
      {
        'title': 'Blood Champion',
        'description': 'Donate blood 10 times',
        'icon': Icons.military_tech,
        'color': Colors.amber,
        'unlocked': false,
        'progress': 0.3, // 3 out of 10 donations
      },
      {
        'title': 'Community Hero',
        'description': 'Respond to 5 blood requests',
        'icon': Icons.people,
        'color': Colors.blue,
        'unlocked': false,
        'progress': 0.4, // 2 out of 5 responses
      },
      {
        'title': 'Dedicated Donor',
        'description': 'Donate blood consistently for 1 year',
        'icon': Icons.calendar_today,
        'color': Colors.green,
        'unlocked': false,
        'progress': 0.5, // 6 months out of 12
      },
    ];

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Your Achievements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children:
                            achievements.map((achievement) {
                              return _buildAchievementItem(achievement);
                            }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: Size(double.infinity, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildAchievementItem(Map<String, dynamic> achievement) {
    final bool unlocked = achievement['unlocked'];
    final double progress = achievement['progress'];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            unlocked
                ? achievement['color'].withOpacity(0.1)
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              unlocked
                  ? achievement['color'].withOpacity(0.3)
                  : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  unlocked
                      ? achievement['color'].withOpacity(0.2)
                      : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              achievement['icon'],
              color: unlocked ? achievement['color'] : Colors.grey,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: unlocked ? Colors.black : Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  achievement['description'],
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: unlocked ? achievement['color'] : Colors.grey,
                    minHeight: 6,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  unlocked
                      ? 'Completed!'
                      : '${(progress * 100).toInt()}% completed',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        unlocked ? achievement['color'] : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked) Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Future<void> _loadDonationHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot =
          await FirebaseFirestore.instance
              .collection('donations')
              .where('donor_id', isEqualTo: user.uid)
              .orderBy('donation_date', descending: true)
              .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _donationHistory =
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return data;
              }).toList();
        });
      } else {
        // If no donation history exists, create mock data for demonstration
        setState(() {
          _donationHistory = [
            {
              'id': '1',
              'center_name': 'Red Cross Blood Center',
              'donation_date': Timestamp.fromDate(DateTime(2025, 5, 5)),
              'donation_type': 'Whole Blood',
              'amount_ml': 450,
            },
            {
              'id': '2',
              'center_name': 'General Hospital',
              'donation_date': Timestamp.fromDate(DateTime(2025, 2, 12)),
              'donation_type': 'Platelets',
              'amount_ml': 200,
            },
            {
              'id': '3',
              'center_name': 'Community Blood Drive',
              'donation_date': Timestamp.fromDate(DateTime(2024, 11, 8)),
              'donation_type': 'Whole Blood',
              'amount_ml': 450,
            },
          ];
        });
      }
    } catch (e) {
      print('Error loading donation history: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateStatistics() {
    // In a real app, this would be calculated from actual donation data
    // For now, we'll use the donation history or mock data

    int totalDonations = _donationHistory.length;
    // Fixed type conversion issue by explicitly casting to int
    int totalBloodMl = _donationHistory.fold<int>(
      0,
      (sum, donation) => sum + (donation['amount_ml'] as int? ?? 0),
    );
    int livesSaved =
        (totalBloodMl / 500).ceil(); // Rough estimate: 500ml can save 3 lives

    Timestamp? lastDonationTimestamp;
    if (_donationHistory.isNotEmpty) {
      lastDonationTimestamp = _donationHistory.first['donation_date'];
    }

    DateTime? nextEligibleDate;
    if (lastDonationTimestamp != null) {
      // Typically can donate whole blood every 56 days
      nextEligibleDate = lastDonationTimestamp.toDate().add(Duration(days: 56));
    }

    setState(() {
      _statistics = {
        'totalDonations': totalDonations,
        'livesSaved': livesSaved,
        'lastDonation': lastDonationTimestamp,
        'nextEligibleDate': nextEligibleDate,
      };
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final File imageFile = File(image.path);
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');

        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profile_image': downloadUrl});

        setState(() {
          _profileImageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: Icon(Icons.bloodtype),
                    ),
                    items:
                        _bloodGroups.map((group) {
                          return DropdownMenuItem(
                            value: group,
                            child: Text(group),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBloodGroup = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateProfile();
                },
                child: Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'blood_group': _selectedBloodGroup,
            'updated_at': FieldValue.serverTimestamp(),
          });

      // Update local data
      setState(() {
        widget.userData['name'] = _nameController.text.trim();
        widget.userData['phone'] = _phoneController.text.trim();
        widget.userData['address'] = _addressController.text.trim();
        widget.userData['blood_group'] = _selectedBloodGroup;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Notification Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Blood Request Alerts'),
                  subtitle: Text('Get notified about nearby blood requests'),
                  value: true,
                  onChanged: (value) {},
                ),
                SwitchListTile(
                  title: Text('Donation Reminders'),
                  subtitle: Text(
                    'Remind me when I\'m eligible to donate again',
                  ),
                  value: true,
                  onChanged: (value) {},
                ),
                SwitchListTile(
                  title: Text('Campaign Updates'),
                  subtitle: Text('Get updates about blood donation campaigns'),
                  value: false,
                  onChanged: (value) {},
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Notification settings updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  void _showPrivacySettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Privacy Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text('Profile Visibility'),
                  subtitle: Text('Allow others to see my profile'),
                  value: true,
                  onChanged: (value) {},
                ),
                SwitchListTile(
                  title: Text('Location Sharing'),
                  subtitle: Text('Share my location for nearby blood requests'),
                  value: true,
                  onChanged: (value) {},
                ),
                SwitchListTile(
                  title: Text('Donation History'),
                  subtitle: Text('Show my donation history to others'),
                  value: false,
                  onChanged: (value) {},
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Privacy settings updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: Text('Save'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Help & Support'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.help_outline, color: Colors.blue),
                  title: Text('FAQs'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to FAQs
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.contact_support_outlined,
                    color: Colors.green,
                  ),
                  title: Text('Contact Support'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to contact support
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.report_problem_outlined,
                    color: Colors.orange,
                  ),
                  title: Text('Report an Issue'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to report issue
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('About LifeFlow'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.bloodtype, size: 40, color: Colors.red),
                ),
                SizedBox(height: 16),
                Text(
                  'LifeFlow',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                SizedBox(height: 16),
                Text(
                  'LifeFlow is a blood donation app that connects blood donors with those in need. Our mission is to save lives by making blood donation easier and more accessible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.language, color: Colors.blue),
                      onPressed: () {
                        // Open website
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.email, color: Colors.red),
                      onPressed: () {
                        // Send email
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.facebook, color: Colors.indigo),
                      onPressed: () {
                        // Open Facebook
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.share, color: Colors.green),
                      onPressed: () {
                        // Replaced Share.share with a simple SnackBar message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sharing app info...')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: EdgeInsets.only(bottom: 20),
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: Colors.blue),
                  title: Text('Edit Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditProfileDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.notifications, color: Colors.orange),
                  title: Text('Notification Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _showNotificationSettingsDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.security, color: Colors.green),
                  title: Text('Privacy Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPrivacySettingsDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.help_outline, color: Colors.purple),
                  title: Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                    _showHelpSupportDialog();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.teal),
                  title: Text('About LifeFlow'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: _isDarkMode ? Colors.amber : Colors.indigo,
                  ),
                  title: Text('Toggle Theme'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _isDarkMode = !_isDarkMode;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isDarkMode
                              ? 'Dark mode enabled'
                              : 'Light mode enabled',
                        ),
                      ),
                    );
                  },
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => LoginPage()),
                        (route) => false,
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error signing out')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showDonationDetailsDialog(Map<String, dynamic> donation) {
    final donationDate = donation['donation_date'] as Timestamp?;
    final formattedDate =
        donationDate != null
            ? DateFormat('MMMM d, yyyy').format(donationDate.toDate())
            : 'Unknown date';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Donation Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Center', donation['center_name'] ?? 'Unknown'),
                _buildDetailRow('Date', formattedDate),
                _buildDetailRow('Type', donation['donation_type'] ?? 'Unknown'),
                _buildDetailRow('Amount', '${donation['amount_ml'] ?? 0} ml'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your donation helped save up to ${(donation['amount_ml'] ?? 0) ~/ 150} lives!',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Replaced Share.share with a simple SnackBar message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sharing donation details...')),
                  );
                },
                icon: Icon(Icons.share),
                label: Text('Share'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  void _showAllDonationsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DonationHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: _isDarkMode ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
            onPressed: _showSettingsBottomSheet,
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 20),
                      _buildDonationStats(),
                      SizedBox(height: 20),
                      _buildProfileInfo(),
                      SizedBox(height: 20),
                      _buildDonationHistory(),
                      SizedBox(height: 20),
                      _buildCompatibilityInfo(),
                      SizedBox(height: 20),
                      _buildLogoutButton(),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Hero(
                tag: 'profile_image',
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor:
                      _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                  backgroundImage:
                      _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : null,
                  child:
                      _profileImageUrl == null
                          ? Icon(
                            Icons.person,
                            size: 60,
                            color:
                                _isDarkMode
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade400,
                          )
                          : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            _isDarkMode ? Colors.grey.shade800 : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            widget.userData['name'] ?? 'User Name',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _isDarkMode
                      ? Colors.red.shade900.withOpacity(0.3)
                      : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDarkMode ? Colors.red.shade800 : Colors.red.shade100,
              ),
            ),
            child: Text(
              'Blood Type: ${widget.userData['blood_group'] ?? 'Unknown'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isDarkMode ? Colors.red.shade300 : Colors.red,
              ),
            ),
          ),
          if (_statistics['nextEligibleDate'] != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _isDarkMode
                        ? Colors.green.shade900.withOpacity(0.3)
                        : Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _isDarkMode
                          ? Colors.green.shade800
                          : Colors.green.shade100,
                ),
              ),
              child: Text(
                'Next Eligible Donation: ${DateFormat('MMM d, yyyy').format(_statistics['nextEligibleDate'])}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.green.shade300 : Colors.green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDonationStats() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Impact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Donations',
                value: _statistics['totalDonations'].toString(),
                icon: Icons.bloodtype,
                color: Colors.red,
              ),
              _buildStatItem(
                label: 'Lives Saved',
                value: _statistics['livesSaved'].toString(),
                icon: Icons.favorite,
                color: Colors.pink,
              ),
              _buildStatItem(
                label: 'Badges',
                value: '3',
                icon: Icons.military_tech,
                color: Colors.amber,
              ),
            ],
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAchievementsDialog, // Connect to the new function
            icon: Icon(Icons.emoji_events),
            label: Text('View Achievements'),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isDarkMode ? Colors.amber.shade700 : Colors.amber.shade100,
              foregroundColor:
                  _isDarkMode ? Colors.white : Colors.amber.shade900,
              elevation: 0,
              minimumSize: Size(double.infinity, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                _isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: _isDarkMode ? color.withOpacity(0.8) : color,
            size: 24,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: _isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showEditProfileDialog,
                icon: Icon(Icons.edit),
                label: Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(color: Theme.of(context).primaryColor),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: widget.userData['email'] ?? 'Not provided',
          ),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: widget.userData['phone'] ?? 'Not provided',
          ),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: widget.userData['address'] ?? 'Not provided',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  _isDarkMode
                      ? Colors.red.shade900.withOpacity(0.3)
                      : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  _isDarkMode
                      ? Colors.red.shade300
                      : Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        _isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                    color: _isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHistory() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Donation History',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              TextButton.icon(
                onPressed: _showAllDonationsDialog,
                icon: Icon(Icons.history, size: 18),
                label: Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _donationHistory.isEmpty
              ? Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bloodtype_outlined,
                      size: 48,
                      color:
                          _isDarkMode
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No donation history yet',
                      style: TextStyle(
                        color:
                            _isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to donation centers
                      },
                      icon: Icon(Icons.add),
                      label: Text('Donate Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children:
                    _donationHistory.take(3).map((donation) {
                      final donationDate =
                          donation['donation_date'] as Timestamp?;
                      final formattedDate =
                          donationDate != null
                              ? DateFormat(
                                'MMMM d, yyyy',
                              ).format(donationDate.toDate())
                              : 'Unknown date';

                      return _buildDonationItem(
                        center: donation['center_name'] ?? 'Unknown',
                        date: formattedDate,
                        donationType: donation['donation_type'] ?? 'Unknown',
                        onTap: () => _showDonationDetailsDialog(donation),
                      );
                    }).toList(),
              ),
        ],
      ),
    );
  }

  Widget _buildDonationItem({
    required String center,
    required String date,
    required String donationType,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    _isDarkMode
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bloodtype,
                color:
                    _isDarkMode
                        ? Colors.red.shade300
                        : Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    date,
                    style: TextStyle(
                      color:
                          _isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    _isDarkMode
                        ? Colors.red.shade900.withOpacity(0.3)
                        : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                donationType,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      _isDarkMode
                          ? Colors.red.shade300
                          : Theme.of(context).primaryColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilityInfo() {
    // Blood compatibility information
    Map<String, List<String>> canDonateTo = {
      'A+': ['A+', 'AB+'],
      'A-': ['A+', 'A-', 'AB+', 'AB-'],
      'B+': ['B+', 'AB+'],
      'B-': ['B+', 'B-', 'AB+', 'AB-'],
      'AB+': ['AB+'],
      'AB-': ['AB+', 'AB-'],
      'O+': ['A+', 'B+', 'AB+', 'O+'],
      'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    };

    Map<String, List<String>> canReceiveFrom = {
      'A+': ['A+', 'A-', 'O+', 'O-'],
      'A-': ['A-', 'O-'],
      'B+': ['B+', 'B-', 'O+', 'O-'],
      'B-': ['B-', 'O-'],
      'AB+': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
      'AB-': ['A-', 'B-', 'AB-', 'O-'],
      'O+': ['O+', 'O-'],
      'O-': ['O-'],
    };

    String bloodGroup = widget.userData['blood_group'] ?? 'Unknown';
    List<String> donateToList = canDonateTo[bloodGroup] ?? [];
    List<String> receiveFromList = canReceiveFrom[bloodGroup] ?? [];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Blood Compatibility',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _isDarkMode
                            ? Colors.green.shade900.withOpacity(0.3)
                            : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _isDarkMode
                              ? Colors.green.shade800
                              : Colors.green.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You Can Donate To',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              _isDarkMode
                                  ? Colors.green.shade300
                                  : Colors.green.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children:
                            donateToList.map((type) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isDarkMode
                                          ? Colors.green.shade800
                                          : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _isDarkMode
                                            ? Colors.white
                                            : Colors.green.shade800,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _isDarkMode
                            ? Colors.blue.shade900.withOpacity(0.3)
                            : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _isDarkMode
                              ? Colors.blue.shade800
                              : Colors.blue.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You Can Receive From',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              _isDarkMode
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children:
                            receiveFromList.map((type) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isDarkMode
                                          ? Colors.blue.shade800
                                          : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _isDarkMode
                                            ? Colors.white
                                            : Colors.blue.shade800,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  _isDarkMode
                      ? Colors.orange.shade900.withOpacity(0.3)
                      : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isDarkMode
                        ? Colors.orange.shade800
                        : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color:
                      _isDarkMode
                          ? Colors.orange.shade300
                          : Colors.orange.shade800,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Blood type compatibility is important for safe transfusions. In emergencies, O- is the universal donor and AB+ is the universal recipient.',
                    style: TextStyle(
                      color:
                          _isDarkMode
                              ? Colors.orange.shade300
                              : Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            await FirebaseAuth.instance.signOut();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => LoginPage()),
              (route) => false,
            );
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error signing out')));
          }
        },
        icon: Icon(Icons.logout),
        label: Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isDarkMode ? Colors.red.shade900 : Colors.red.shade50,
          foregroundColor: _isDarkMode ? Colors.white : Colors.red,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _isDarkMode ? Colors.red.shade800 : Colors.red.shade200,
            ),
          ),
        ),
      ),
    );
  }
}