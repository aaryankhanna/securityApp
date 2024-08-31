import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(SafetyApp());
}

class SafetyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Girl Safety App',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: SafetyHomePage(),
    );
  }
}

class SafetyHomePage extends StatefulWidget {
  @override
  _SafetyHomePageState createState() => _SafetyHomePageState();
}

class _SafetyHomePageState extends State<SafetyHomePage> {
  int _buttonPressCount = 0;
  DateTime _lastPressTime = DateTime.now();
  List<String> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();

    if (!kIsWeb) {
      _requestPermissions(); // Only request permissions if not on the web
    }
  }

  void _requestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Request necessary permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.sms,
        Permission.phone,
        Permission.locationWhenInUse
      ].request();

      // Check the status of each permission
      if (statuses[Permission.sms] != PermissionStatus.granted ||
          statuses[Permission.phone] != PermissionStatus.granted ||
          statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
        print('Permissions not granted. Some features may not work.');
      }
    }
  }

  void _loadEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emergencyContacts = prefs.getStringList('emergencyContacts') ?? [];
    });
  }

  void _handleButtonPress() {
    final now = DateTime.now();

    if (now.difference(_lastPressTime) <= Duration(seconds: 2)) {
      _buttonPressCount++;
    } else {
      _buttonPressCount = 1; // Reset count if more than 2 seconds have passed
    }

    _lastPressTime = now;
    print('Button pressed $_buttonPressCount times.');

    if (_buttonPressCount >= 3) {
      _triggerEmergency();
      _buttonPressCount = 0; // Reset the count after triggering the emergency
    }
  }

  void _triggerEmergency() async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    print(position);
    for (String contact in _emergencyContacts) {
      _sendSMS(contact, 'Emergency! My location: ${position.latitude}, ${position.longitude}');
      _makePhoneCall(contact);
    }

    _buttonPressCount = 0;
  }

  void _sendSMS(String phoneNumber, String message) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      print('Could not launch SMS');
    }
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri telUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      print('Could not launch Phone Call');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Girl Safety App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _handleButtonPress,
              child: Text('Emergency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ContactsPage()),
                );
              },
              child: Text('Manage Emergency Contacts'),
            ),
          ],
        ),
      ),
    );
  }
}

// ContactsPage code remains the same.


class ContactsPage extends StatefulWidget {
  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<String> _contacts = [];
  TextEditingController _contactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contacts = prefs.getStringList('emergencyContacts') ?? [];
    });
  }

  void _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('emergencyContacts', _contacts);
  }

  void _addContact() {
    if (_contactController.text.isNotEmpty) {
      setState(() {
        _contacts.add(_contactController.text);
        _contactController.clear();
      });
      _saveContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Emergency Contacts'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Add Emergency Contact',
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addContact,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_contacts[index]),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _contacts.removeAt(index);
                      });
                      _saveContacts();
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
