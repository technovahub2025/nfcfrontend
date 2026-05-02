import 'dart:convert';



import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';



import 'dart:async';



import 'package:nfc/screen/enhanced_nfc_scanner.dart';
import 'package:nfc/screen/business_details_page.dart';

import 'package:nfc/screen/nfc_data_display_screen.dart';
import 'package:nfc/services/nfc_profile_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:permission_handler/permission_handler.dart';



class TopContainerExample extends StatefulWidget {



  const TopContainerExample({super.key});







  @override



  State<TopContainerExample> createState() => _TopContainerExampleState();











}







class _TopContainerExampleState extends State<TopContainerExample> {



  String userName = 'User';



  String userEmail = 'user@example.com';



  String greeting = 'Good Morning';

  

  // Controllers for data input

  TextEditingController nameController = TextEditingController();

  TextEditingController emailController = TextEditingController();

  TextEditingController phoneController = TextEditingController();

  TextEditingController companyController = TextEditingController();

  TextEditingController addressController = TextEditingController();

  List<Map<String, dynamic>> scannedDataList = [];



  // QR Scanner variables

  bool _isQRScanning = false;

  final MobileScannerController _qrScannerController = MobileScannerController();



  @override



  void initState() {



    super.initState();



    _loadUserData();



    _updateGreeting();



    



    // Update greeting every minute



    Timer.periodic(Duration(minutes: 1), (timer) {



      if (mounted) {



        _updateGreeting();



      }



    });



  }







  Future<void> _loadUserData() async {



    try {



      SharedPreferences prefs = await SharedPreferences.getInstance();



      String? email = prefs.getString('user_email');



      if (email != null) {



        setState(() {



          userEmail = email;



          // Extract name from email (before @ symbol)



          userName = email.split('@')[0];



          // Capitalize first letter



          userName = userName[0].toUpperCase() + userName.substring(1);



        });



      }



    } catch (e) {



      if (kDebugMode) {

        print('Error loading user data: $e');

      }



    }



  }







  void _updateGreeting() {



    final hour = DateTime.now().hour;



    String newGreeting;



    



    if (hour >= 5 && hour < 12) {



      newGreeting = 'Good Morning ';



    } else if (hour >= 12 && hour < 17) {



      newGreeting = 'Good Afternoon ';



    } else if (hour >= 17 && hour < 21) {



      newGreeting = 'Good Evening ';



    } else {



      newGreeting = 'Good Night ';



    }



    



    if (mounted && newGreeting != greeting) {



      setState(() {



        greeting = newGreeting;



      });



    }



  }



  void _addScannedData(Map<String, dynamic> data) {

    setState(() {

      scannedDataList.insert(0, {

        ...data,

        'timestamp': DateTime.now().toString().substring(0, 19),

      });

    });

  }



  void _clearAllFields() {

    nameController.clear();

    emailController.clear();

    phoneController.clear();

    companyController.clear();

    addressController.clear();

  }



  // QR Scanner Methods

  void _toggleQRScanner() async {

    // Request camera permission first

    final permission = await Permission.camera.request();

    if (!permission.isGranted) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Row(

            children: [

              Icon(Icons.error, color: Colors.white, size: 20),

              SizedBox(width: 8),

              Text('Camera permission is required to scan QR codes'),

            ],

          ),

          backgroundColor: Colors.orange,

          duration: Duration(seconds: 3),

        ),

      );

      return;

    }



    setState(() {

      _isQRScanning = !_isQRScanning;

    });

    

    if (_isQRScanning) {

      _qrScannerController.start();

    } else {

      _qrScannerController.stop();

    }

  }



  void _handleQRCode(String qrData) async {
    // Stop QR scanner
    setState(() {
      _isQRScanning = false;
    });
    _qrScannerController.stop();

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            SizedBox(width: 16),
            Text('Processing QR code...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 10),
      ),
    );

    try {
      // Check if QR data contains profile URL
      final profileId = NFCProfileService.extractProfileIdFromUrl(qrData);
      
      Map<String, dynamic> userData = {};
      
      if (profileId != null) {
        // Fetch profile from API
        final profileData = await NFCProfileService.getProfile(profileId,context);
        if (profileData != null) {
          userData = {
            ...profileData,
            'type': 'NFC_PROFILE',
            'profileId': profileId,
          };
          
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.person, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Profile loaded successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // Profile not found
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Profile not found'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      } else {
        // Try to parse as JSON
        try {
          final Map<String, dynamic> qrContent = jsonDecode(qrData);
          userData = {
            ...qrContent,
            'type': 'QR',
          };
        } catch (e) {
          // If not JSON, create simple data
          userData = {
            'qr_data': qrData,
            'type': 'QR',
            'name': 'QR Scanned Data',
            'bio': qrData,
            'email': '',
            'phone': '',
            'company': '',
            'address': '',
            'website': '',
            'linkedin': '',
            'instagram': '',
            'facebook': '',
            'twitter': '',
          };
        }
      }
      
      // Add to scanned data list
      _addScannedData(userData);
      
      // Navigate to NFC data display screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NFCDataDisplayScreen(userData: userData),
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Error processing QR code'),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } 

  Future<void> _openBusinessDetailsPage() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const BusinessDetailsPage(),
      ),
    );

    if (result != null && mounted) {
      _addScannedData(result);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NFCDataDisplayScreen(userData: result),
        ),
      );
    }
  }



  @override

  void dispose() {

    _qrScannerController.dispose();

    super.dispose();

  }



  String _getNfcData() {

    return 'Name: ${nameController.text}\n'

           'Email: ${emailController.text}\n'

           'Phone: ${phoneController.text}\n'

           'Company: ${companyController.text}\n'

           'Address: ${addressController.text}';

  }



  @override



  Widget build(BuildContext context) {



    return Scaffold(



      backgroundColor: Color(0xFFE0F2F7), 



      drawer: _buildDrawer(context),



      



      body: _isQRScanning 

        ? _buildQRScanner()

        : SafeArea(



          child: Padding(



            padding: const EdgeInsets.all(16.0),



            child: Column(



              children: [



              



              Row(



                children: [



                  Builder(



                    builder: (context) => IconButton(



                      icon: Icon(Icons.menu, color: Colors.black87, size: 24),



                      onPressed: () => Scaffold.of(context).openDrawer(),



                    ),



                  ),



                  


                  SizedBox(width: 12),



                 



                ],



              ),



              SizedBox(height: 20),



              



              // Greeting Section



              Container(



                width: double.infinity,



                padding: EdgeInsets.all(20),



                decoration: BoxDecoration(



                  color: Colors.white,



                  borderRadius: BorderRadius.circular(12),



                  boxShadow: [



                    BoxShadow(



                      // ignore: deprecated_member_use



                      // ignore: deprecated_member_use

                      color: Colors.black.withOpacity(0.1),



                      blurRadius: 5,



                      offset: Offset(0, 2),



                    ),



                  ],



                ),



                child: Column(



                  crossAxisAlignment: CrossAxisAlignment.start,



                  children: [



                    Text(



                      greeting,



                      style: TextStyle(



                        fontSize: 24,



                        fontWeight: FontWeight.bold,



                        color: Colors.black87,



                      ),



                    ),



                    SizedBox(height: 8),



                    Text(



                      '$userName, welcome back!',



                      style: TextStyle(



                        fontSize: 16,



                        color: Colors.grey[600],



                      ),



                    ),



                  ],



                ),



              ),



              SizedBox(height: 30),







              // Quick Action Buttons







              SizedBox(height: 30),







             







             







            



            



              SizedBox(height: 20),







            



              SizedBox(height: 10),







              // Scan Options Section



              Row(



                children: [



                  Expanded(



                    child: _buildQuickActionButton(



                      context: context,



                      icon: Icons.nfc,



                      label: 'Scan NFC',



                      color: Color(0xFF2196F3),



                    ),



                  ),



              



                  
                  SizedBox(width: 16),



                  Expanded(



                    child: _buildQuickActionButton(



                      context: context,



                      icon: Icons.qr_code_scanner,



                      label: 'Scan QR',



                      color: Color(0xFF9C27B0),



                    ),



                  ),



                ],



              ),



              SizedBox(height: 20,),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openBusinessDetailsPage,
                  icon: const Icon(Icons.business_center, color: Colors.white),
                  label: const Text('Add Business Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),



              







            ],



          ),



        ),



      ),







     



    );











  



  }







  Widget _buildDrawer(BuildContext context) {



    return Drawer(



      child: ListView(



        padding: EdgeInsets.zero,



        children: [



          // Drawer Header



          DrawerHeader(



            decoration: BoxDecoration(



              color: Color(0xFF1E88E5), 



            ),



            child: Column(



              crossAxisAlignment: CrossAxisAlignment.start,



              children: [



                CircleAvatar(



                  radius: 30,



                  backgroundColor: Colors.white,



                  child: Icon(



                    Icons.person,



                    size: 40,



                    color: Color(0xFF1E88E5),



                  ),



                ),



                SizedBox(height: 15),



                Text(



                  'Welcome, $userName',



                  style: TextStyle(



                    color: Colors.white,



                    fontSize: 18,



                    fontWeight: FontWeight.bold,



                  ),



                ),



                SizedBox(height: 5),



                Text(



                  userEmail,



                  style: TextStyle(



                    color: Colors.white70,



                    fontSize: 14,



                  ),



                ),



              ],



            ),



          ),



          



          // Drawer Items



        

       





        ],



      ),



    );



  }







  Widget _buildQuickActionButton( {







    required BuildContext context,



    



    required IconData icon,



    required String label,



    required Color color,



  }) {



    return GestureDetector(



      onTap: () {



        if (label == 'Scan QR') {



          _toggleQRScanner();



        } else if (label == 'Scan NFC') {



          Navigator.push(



            context,



            MaterialPageRoute(



              builder: (context) => EnhancedNFCScanner(



                onDataScanned: (data) {



                  _addScannedData({...data, 'type': 'NFC'});



                },



              ),



            ),



          );



        } else if (label == 'Write NFC') {



          if (nameController.text.isNotEmpty) {



            Navigator.push(



              context,



              MaterialPageRoute(



                builder: (context) => EnhancedNFCScanner(



                  writeData: _getNfcData(),



                ),



              ),



            );



          }



        }



      },



      child: Container(



        width: 80,



        height: 80,



        decoration: BoxDecoration(



          color: color,



          borderRadius: BorderRadius.circular(16),



          boxShadow: [



            BoxShadow(



              // ignore: deprecated_member_use



              // ignore: deprecated_member_use

              color: Colors.black.withOpacity(0.2),



              blurRadius: 8,



              offset: Offset(0, 4),



            ),



          ],



        ),



        child: Column(



          mainAxisAlignment: MainAxisAlignment.center,



          children: [



            Icon(



              icon,



              color: Colors.white,



              size: 30,



            ),



            SizedBox(height: 8),



            Text(



              label,



              style: TextStyle(



                fontSize: 12,



                fontWeight: FontWeight.w600,



                color: Colors.white,



              ),



            ),



          ],



        ),



      ),



    );



  }

















  Widget _buildQRScanner() {

    return Container(

      color: Colors.black,

      child: Column(

        children: [

          // QR Scanner Header

          Container(

            padding: const EdgeInsets.all(16),

            color: Colors.white,

            child: Row(

              children: [

                IconButton(

                  icon: const Icon(Icons.close, color: Colors.black),

                  onPressed: () => _toggleQRScanner(),

                ),

                const Expanded(

                  child: Text(

                    'Scan QR Code',

                    style: TextStyle(

                      fontSize: 18,

                      fontWeight: FontWeight.w600,

                      color: Colors.black,

                    ),

                    textAlign: TextAlign.center,

                  ),

                ),

                const SizedBox(width: 48), // Balance the close button

              ],

            ),

          ),

          

          // QR Scanner View

          Expanded(

            child: Container(

              margin: const EdgeInsets.all(16),

              decoration: BoxDecoration(

                borderRadius: BorderRadius.circular(12),

                border: Border.all(color: Colors.blue.shade300),

              ),

              child: ClipRRect(

                borderRadius: BorderRadius.circular(12),

                child: MobileScanner(

                  controller: _qrScannerController,

                  onDetect: (capture) {

                    if (kDebugMode) {

                      print('MobileScanner detected something: ${capture.barcodes.length} barcodes');

                    }

                    final List<Barcode> barcodes = capture.barcodes;

                    for (final barcode in barcodes) {

                      if (kDebugMode) {

                        print('Barcode found: ${barcode.rawValue}');

                      }

                      if (barcode.rawValue != null) {

                        _handleQRCode(barcode.rawValue!);

                        break;

                      }

                    }

                  },

                ),

              ),

            ),

          ),

          

          // Instructions

          Container(

            padding: const EdgeInsets.all(16),

            color: Colors.white,

            child: Text(

              'Position QR code in frame to scan',

              style: TextStyle(

                color: Colors.grey[600],

                fontSize: 14,

              ),

              textAlign: TextAlign.center,

            ),

          ),

        ],

      ),

    );

  }

}
