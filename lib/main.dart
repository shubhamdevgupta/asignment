import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp(); // Ensure Firebase is initialized
    if (task == "fetchLocationTask") {
      print("Executing background location fetch...");
      await fetchLocation();
    }
    return Future.value(true);
  });
}

Future<void> fetchLocation() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Background: Location services are disabled. Cannot fetch location.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print("Background: Location permissions are denied. Cannot fetch location.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Log the background location fetch
    print("Background location fetched at ${DateTime.now()}: Latitude ${position.latitude}, Longitude ${position.longitude}");

    // Save location to Firestore
    CollectionReference locations = FirebaseFirestore.instance.collection('locations');
    await locations.add({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print("Error fetching background location: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(); // Initialize Firebase
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

  print("Background fetch initialized.");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Position? currentPosition;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startPeriodicLocationUpdates();
    _scheduleBackgroundTask();
  }

  void _startPeriodicLocationUpdates() {
    print("Starting foreground periodic location updates.");
    _timer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await _getCurrentLocation();
    });
  }

  void _scheduleBackgroundTask() {
    Workmanager().registerPeriodicTask(
      "fetchLocationTask", // Unique task name
      "fetchLocation", // Task name
      frequency: Duration(minutes: 15), // Minimum interval for periodic tasks
      constraints: Constraints(
        networkType: NetworkType.connected, // Ensure the device is connected
      ),
    );
    print("Background task scheduled.");
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled. Please enable them.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        print("Location permissions are denied. Cannot fetch location.");
        return;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print("Foreground location fetched: Latitude ${position.latitude}, Longitude ${position.longitude}");
      setState(() {
        currentPosition = position;
      });
      saveLocationToFirestore(currentPosition!.latitude, currentPosition!.longitude);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  Future<void> saveLocationToFirestore(double latitude, double longitude) async {
    print('=====storing in flutter database====');
    try {
      // Reference Firestore
      CollectionReference locations = FirebaseFirestore.instance.collection('locations');

      // Create data to store
      Map<String, dynamic> locationData = {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(), // Firebase server timestamp
      };

      // Add data to Firestore
      await locations.add(locationData);

      print("Location data saved: $locationData");
    } catch (e) {
      print("Error saving location to Firestore: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Location Fetch Example")),
      body: Center(
        child: currentPosition == null
            ? CircularProgressIndicator()
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Latitude: ${currentPosition!.latitude}, Longitude: ${currentPosition!.longitude}",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            Text(
              "Logs are available in the console to check background fetch functionality.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
