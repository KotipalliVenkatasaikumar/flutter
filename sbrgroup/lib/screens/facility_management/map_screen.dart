import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final Function(String latitude, String longitude, String radius)
      onGeofenceSelected;

  MapScreen({required this.onGeofenceSelected});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  final double _radius = 30; // Set default radius to 20 meters

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _getCurrentLocation() async {
    Position position = await _determinePosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _selectedLocation =
          _currentLocation; // Initially set selected location to current location
      _moveCameraToLocation(_currentLocation!);
    });
  }

  void _moveCameraToLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 18.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Geo Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              if (_selectedLocation == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a location')),
                );
              } else {
                widget.onGeofenceSelected(
                  _selectedLocation!.latitude.toString(),
                  _selectedLocation!.longitude.toString(),
                  _radius.toString(),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _moveCameraToLocation(_currentLocation!);
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation!,
                    zoom: 18.0,
                  ),
                  onTap: (LatLng location) {
                    setState(() {
                      _selectedLocation =
                          location; // Update selected location only on tap
                    });
                  },
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected-location'),
                            position: _selectedLocation!,
                          ),
                        }
                      : {},
                  circles: {
                    Circle(
                      circleId: const CircleId('selected-radius'),
                      center: _selectedLocation ?? _currentLocation!,
                      radius: _radius,
                      fillColor: Colors.blue.withOpacity(0.5),
                      strokeColor: Colors.blue,
                      strokeWidth: 1,
                    ),
                  },
                ),
              ],
            ),
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }
}
