
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Google Maps Location',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const LocationMapScreen(),
    );
  }
}

class LocationMapScreen extends StatefulWidget {
  const LocationMapScreen({super.key});

  @override
  State<LocationMapScreen> createState() =>
      _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  GoogleMapController? _mapController;
  Timer? _locationTimer;

  LatLng? _currentLocation;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final List<LatLng> _locationHistory = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Check whether location services are enabled.
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Please enable your device location service.',
        );
      }

      // Check location permission.
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Enable it in app settings.',
        );
      }

      // Get the initial GPS position.
      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      _updateLocation(position);

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      // Fetch location every 10 seconds.
      _locationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _getLatestLocation(),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  Future<void> _getLatestLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      _updateLocation(position);
    } catch (e) {
      debugPrint('Unable to update location: $e');
    }
  }

  void _updateLocation(Position position) {
    final LatLng newLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    // Save the new location for polyline tracking.
    _locationHistory.add(newLocation);

    setState(() {
      _currentLocation = newLocation;

      // Update the marker and its information window.
      _markers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: newLocation,
            infoWindow: InfoWindow(
              title: 'My current location',
              snippet:
                  'Latitude: ${position.latitude.toStringAsFixed(6)}, '
                  'Longitude: ${position.longitude.toStringAsFixed(6)}',
            ),
          ),
        );

      // Draw a polyline through the recorded locations.
      _polylines
        ..clear()
        ..add(
          Polyline(
            polylineId: const PolylineId('location_path'),
            points: List<LatLng>.of(_locationHistory),
            color: Colors.blue,
            width: 5,
          ),
        );
    });

    // Animate the map to the latest position.
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(newLocation),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // If GPS loaded before the map controller was ready,
    // animate to the current position now.
    if (_currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 16,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Current Location'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _initializeLocation();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 16,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                ),
    );
  }
}
