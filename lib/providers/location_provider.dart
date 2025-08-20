import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'dart:math' as Math;

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  String? _errorMessage;
  GoogleMapController? _mapController;
  LatLng? _driverLocation;
  String? _driverVehicleType;
  DirectionsResult? _currentDirections;

  // Add your Google Maps API key here
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
  static const String _geocodingBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  Position? get currentPosition => _currentPosition;
  String? get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  GoogleMapController? get mapController => _mapController;
  LatLng? get driverLocation => _driverLocation;
  String? get driverVehicleType => _driverVehicleType;
  DirectionsResult? get currentDirections => _currentDirections;

  Future<bool> requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Location services are disabled.';
      notifyListeners();
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permissions are denied';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMessage =
          'Location permissions are permanently denied, we cannot request permissions.';
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<void> getCurrentLocation() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _getAddressFromCoordinates(_currentPosition!);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to get current location: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        _currentAddress = _formatAddress(place);
      }
    } catch (e) {
      _currentAddress = 'Unknown location';
      print('Error getting address from coordinates: $e');
    }
  }

  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations[0].latitude, locations[0].longitude);
      }
    } catch (e) {
      _errorMessage = 'Failed to get coordinates: $e';
      notifyListeners();
    }
    return null;
  }

  // IMPROVED: Better geocoding with multiple fallback methods
  Future<String?> getAddressFromCoordinates(LatLng coordinates) async {
    try {
      // Method 1: Try native geocoding first
      String? address = await _getNativeGeocodedAddress(coordinates);
      if (address != null && address != 'Unknown location') {
        return address;
      }

      // Method 2: Try Google Geocoding API if native fails
      if (_apiKey != 'YOUR_GOOGLE_MAPS_API_KEY') {
        address = await _getGoogleGeocodedAddress(coordinates);
        if (address != null) {
          return address;
        }
      }

      // Method 3: Fallback with basic formatting
      return 'Location: ${coordinates.latitude.toStringAsFixed(6)}, ${coordinates.longitude.toStringAsFixed(6)}';
    } catch (e) {
      print('Error in getAddressFromCoordinates: $e');
      return 'Location: ${coordinates.latitude.toStringAsFixed(4)}, ${coordinates.longitude.toStringAsFixed(4)}';
    }
  }

  // Native geocoding with better error handling
  Future<String?> _getNativeGeocodedAddress(LatLng coordinates) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return _formatAddress(place);
      }
    } catch (e) {
      print('Native geocoding failed: $e');
    }
    return null;
  }

  // Google Geocoding API as fallback
  Future<String?> _getGoogleGeocodedAddress(LatLng coordinates) async {
    try {
      final String url =
          '$_geocodingBaseUrl?'
          'latlng=${coordinates.latitude},${coordinates.longitude}&'
          'key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return result['formatted_address'];
        }
      }
    } catch (e) {
      print('Google geocoding failed: $e');
    }
    return null;
  }

  // Better address formatting
  String _formatAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.name != null && place.name!.isNotEmpty) {
      addressParts.add(place.name!);
    }

    if (place.street != null &&
        place.street!.isNotEmpty &&
        place.street != place.name) {
      addressParts.add(place.street!);
    }

    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      addressParts.add(place.subLocality!);
    }

    if (place.locality != null && place.locality!.isNotEmpty) {
      addressParts.add(place.locality!);
    }

    if (place.administrativeArea != null &&
        place.administrativeArea!.isNotEmpty) {
      addressParts.add(place.administrativeArea!);
    }

    if (addressParts.isEmpty) {
      return 'Unknown location';
    }

    return addressParts
        .take(3)
        .join(', '); // Limit to 3 parts to avoid too long addresses
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  // IMPROVED: Better directions with caching and error handling
  Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      // Check if we already have directions for the same route
      if (_currentDirections != null &&
          _currentDirections!.isSameRoute(origin, destination)) {
        return _currentDirections;
      }

      // If no API key, return fallback route
      if (_apiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        return _createFallbackDirections(origin, destination);
      }

      final String url =
          '$_directionsBaseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'alternatives=false&'
          'avoid=tolls&'
          'units=metric&'
          'key=$_apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          _currentDirections = DirectionsResult.fromJson(
            data['routes'][0],
            origin,
            destination,
          );
          notifyListeners();
          return _currentDirections;
        } else {
          print('Directions API error: ${data['status']}');
          if (data['error_message'] != null) {
            print('Error message: ${data['error_message']}');
          }
          // Return fallback on API error
          return _createFallbackDirections(origin, destination);
        }
      } else {
        print('HTTP error: ${response.statusCode}');
        return _createFallbackDirections(origin, destination);
      }
    } catch (e) {
      print('Error getting directions: $e');
      return _createFallbackDirections(origin, destination);
    }
  }

  // Create fallback directions when API is not available
  DirectionsResult _createFallbackDirections(
    LatLng origin,
    LatLng destination,
  ) {
    final distance = calculateDistance(origin, destination);
    final polylinePoints = createSimpleRoutePolyline(origin, destination);

    // Estimate duration (assuming 40 km/h average speed)
    final durationMinutes = (distance / 1000 / 40 * 60).toInt();

    return DirectionsResult(
      polylinePoints: polylinePoints,
      distance: '${(distance / 1000).toStringAsFixed(1)} km',
      duration: '$durationMinutes min',
      distanceInMeters: distance,
      durationInSeconds: durationMinutes * 60,
      bounds: LatLngBounds(
        southwest: LatLng(
          origin.latitude < destination.latitude
              ? origin.latitude
              : destination.latitude,
          origin.longitude < destination.longitude
              ? origin.longitude
              : destination.longitude,
        ),
        northeast: LatLng(
          origin.latitude > destination.latitude
              ? origin.latitude
              : destination.latitude,
          origin.longitude > destination.longitude
              ? origin.longitude
              : destination.longitude,
        ),
      ),
      origin: origin,
      destination: destination,
    );
  }

  // Clear current directions
  void clearDirections() {
    _currentDirections = null;
    notifyListeners();
  }

  // IMPROVED: Better polyline creation with more realistic curves
  List<LatLng> createSimpleRoutePolyline(LatLng start, LatLng end) {
    List<LatLng> polylinePoints = [];

    double lat1 = start.latitude;
    double lng1 = start.longitude;
    double lat2 = end.latitude;
    double lng2 = end.longitude;

    polylinePoints.add(start);

    // Create intermediate points with slight curve for more realistic look
    int segments = 20;
    for (int i = 1; i < segments; i++) {
      double ratio = i / segments.toDouble();

      // Add slight curve by offsetting perpendicular to the line
      double midLat = lat1 + (lat2 - lat1) * ratio;
      double midLng = lng1 + (lng2 - lng1) * ratio;

      // Add small curve offset (adjust for natural road curves)
      if (i > segments * 0.3 && i < segments * 0.7) {
        double maxOffset = 0.001; // Small offset for curve
        double curveOffset = maxOffset * Math.sin(ratio * Math.pi);

        // Perpendicular offset
        double perpLat = -(lng2 - lng1);
        double perpLng = (lat2 - lat1);
        double perpLength = Math.sqrt(perpLat * perpLat + perpLng * perpLng);

        if (perpLength > 0) {
          perpLat /= perpLength;
          perpLng /= perpLength;

          midLat += perpLat * curveOffset;
          midLng += perpLng * curveOffset;
        }
      }

      polylinePoints.add(LatLng(midLat, midLng));
    }

    polylinePoints.add(end);
    return polylinePoints;
  }

  // Set driver location and vehicle type
  void setDriverLocation(LatLng location, String vehicleType) {
    _driverLocation = location;
    _driverVehicleType = vehicleType;
    notifyListeners();
  }

  // Clear driver location
  void clearDriverLocation() {
    _driverLocation = null;
    _driverVehicleType = null;
    notifyListeners();
  }

  // Create vehicle marker based on vehicle type
  BitmapDescriptor getVehicleIcon(String vehicleType) {
    switch (vehicleType.toLowerCase()) {
      case 'car':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 'auto':
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case 'van':
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      default:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }
}

// IMPROVED: DirectionsResult with route caching
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distance;
  final String duration;
  final double distanceInMeters;
  final int durationInSeconds;
  final LatLngBounds bounds;
  final LatLng origin;
  final LatLng destination;

  DirectionsResult({
    required this.polylinePoints,
    required this.distance,
    required this.duration,
    required this.distanceInMeters,
    required this.durationInSeconds,
    required this.bounds,
    required this.origin,
    required this.destination,
  });

  factory DirectionsResult.fromJson(
    Map<String, dynamic> json,
    LatLng origin,
    LatLng destination,
  ) {
    try {
      final leg = json['legs'][0];
      final polyline = json['overview_polyline']['points'];

      // Decode polyline points
      final decodedPoints = decodePolyline(polyline);
      final polylinePoints =
          decodedPoints
              .map((point) => LatLng(point[0].toDouble(), point[1].toDouble()))
              .toList();

      // Get bounds
      final northeast = json['bounds']['northeast'];
      final southwest = json['bounds']['southwest'];
      final bounds = LatLngBounds(
        northeast: LatLng(northeast['lat'], northeast['lng']),
        southwest: LatLng(southwest['lat'], southwest['lng']),
      );

      return DirectionsResult(
        polylinePoints: polylinePoints,
        distance: leg['distance']['text'],
        duration: leg['duration']['text'],
        distanceInMeters: leg['distance']['value'].toDouble(),
        durationInSeconds: leg['duration']['value'],
        bounds: bounds,
        origin: origin,
        destination: destination,
      );
    } catch (e) {
      print('Error parsing directions JSON: $e');
      // Return basic fallback
      final distance = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      return DirectionsResult(
        polylinePoints: [origin, destination],
        distance: '${(distance / 1000).toStringAsFixed(1)} km',
        duration: '${(distance / 1000 / 40 * 60).toInt()} min',
        distanceInMeters: distance,
        durationInSeconds: (distance / 1000 / 40 * 3600).toInt(),
        bounds: LatLngBounds(
          southwest: LatLng(
            origin.latitude < destination.latitude
                ? origin.latitude
                : destination.latitude,
            origin.longitude < destination.longitude
                ? origin.longitude
                : destination.longitude,
          ),
          northeast: LatLng(
            origin.latitude > destination.latitude
                ? origin.latitude
                : destination.latitude,
            origin.longitude > destination.longitude
                ? origin.longitude
                : destination.longitude,
          ),
        ),
        origin: origin,
        destination: destination,
      );
    }
  }

  // Check if this is the same route to avoid unnecessary API calls
  bool isSameRoute(LatLng newOrigin, LatLng newDestination) {
    const double threshold = 0.001; // ~100 meters
    return (origin.latitude - newOrigin.latitude).abs() < threshold &&
        (origin.longitude - newOrigin.longitude).abs() < threshold &&
        (destination.latitude - newDestination.latitude).abs() < threshold &&
        (destination.longitude - newDestination.longitude).abs() < threshold;
  }
}

// Extension to create polyline from directions result
extension DirectionsPolyline on DirectionsResult {
  Polyline toPolyline({
    String polylineId = 'route',
    Color color = const Color(0xFF2196F3),
    int width = 5,
    List<PatternItem> patterns = const [],
  }) {
    return Polyline(
      polylineId: PolylineId(polylineId),
      points: polylinePoints,
      color: color,
      width: width,
      patterns: patterns,
      geodesic: true, // This makes the line follow the earth's curvature
    );
  }
}
