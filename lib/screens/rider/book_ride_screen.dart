import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/simple_auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/ride_provider.dart';
import '../../utils/app_colors.dart';
import '../../models/ride_model.dart';

class BookRideScreen extends StatefulWidget {
  const BookRideScreen({super.key});

  @override
  State<BookRideScreen> createState() => _BookRideScreenState();
}

class _BookRideScreenState extends State<BookRideScreen>
    with TickerProviderStateMixin {
  final _pickupController = TextEditingController();
  final _dropController = TextEditingController();

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  VehicleType _selectedVehicleType = VehicleType.car;
  double _estimatedFare = 0.0;
  double _distance = 0.0;
  String _estimatedTime = '';

  // NEW: Track polyline state to prevent blinking
  String? _currentRouteId;
  bool _isLoadingRoute = false;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrentLocation();
      _slideController.forward();
      _fadeController.forward();
    });
  }

  Future<void> _initializeCurrentLocation() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    if (locationProvider.currentPosition != null &&
        locationProvider.currentAddress != null) {
      _pickupLocation = LatLng(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
      );
      _pickupController.text = locationProvider.currentAddress!;
      _updateMap();
    }
  }

  void _updateMap() {
    setState(() {
      _markers.clear();
      // Don't clear polylines here to prevent blinking

      if (_pickupLocation != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('pickup'),
            position: _pickupLocation!,
            infoWindow: InfoWindow(title: 'Pickup Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }

      if (_dropLocation != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('drop'),
            position: _dropLocation!,
            infoWindow: InfoWindow(title: 'Drop Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );
      }
    });

    if (_pickupLocation != null && _dropLocation != null) {
      _getDirectionsAndCalculateFare();
    } else if (_pickupLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _pickupLocation!, zoom: 15.0),
        ),
      );
    }
  }

  // IMPROVED: Better route handling with state management
  Future<void> _getDirectionsAndCalculateFare() async {
    if (_pickupLocation == null || _dropLocation == null) return;

    // Create unique route ID to avoid duplicate requests
    final String newRouteId =
        '${_pickupLocation!.latitude},${_pickupLocation!.longitude}-${_dropLocation!.latitude},${_dropLocation!.longitude}';

    // Don't reload if it's the same route
    if (_currentRouteId == newRouteId && !_isLoadingRoute) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    try {
      // Get directions from API
      final directions = await locationProvider.getDirections(
        origin: _pickupLocation!,
        destination: _dropLocation!,
      );

      if (directions != null) {
        // Use actual route distance from directions API
        _distance = directions.distanceInMeters;
        _estimatedTime = directions.duration;

        // Create polyline from directions with unique ID
        final polyline = directions.toPolyline(
          polylineId: 'route_$newRouteId',
          color: AppColors.primary,
          width: 6,
        );

        // Update polylines without clearing (to prevent blinking)
        setState(() {
          _polylines.removeWhere(
            (p) => p.polylineId.value.startsWith('route_'),
          );
          _polylines.add(polyline);
          _currentRouteId = newRouteId;
        });

        // Animate camera to show the entire route
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(directions.bounds, 100),
          );
        }
      } else {
        // Fallback to straight line calculation if API fails
        _createFallbackRoute(newRouteId);
      }

      // Calculate fare using actual distance
      final rideProvider = Provider.of<RideProvider>(context, listen: false);
      _estimatedFare = rideProvider.calculateFare(
        _distance,
        _selectedVehicleType,
      );

      setState(() {
        _isLoadingRoute = false;
      });
    } catch (e) {
      print('Error getting directions: $e');
      _createFallbackRoute(newRouteId);
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _createFallbackRoute(String routeId) {
    if (_pickupLocation != null && _dropLocation != null) {
      final locationProvider = Provider.of<LocationProvider>(
        context,
        listen: false,
      );

      _distance = locationProvider.calculateDistance(
        _pickupLocation!,
        _dropLocation!,
      );

      _estimatedTime = '${(_distance / 1000 / 40 * 60).toInt()} min';

      // Create fallback polyline
      final fallbackPoints = locationProvider.createSimpleRoutePolyline(
        _pickupLocation!,
        _dropLocation!,
      );

      final fallbackPolyline = Polyline(
        polylineId: PolylineId('route_$routeId'),
        points: fallbackPoints,
        color: AppColors.primary.withOpacity(0.7),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        geodesic: true,
      );

      setState(() {
        _polylines.removeWhere((p) => p.polylineId.value.startsWith('route_'));
        _polylines.add(fallbackPolyline);
        _currentRouteId = routeId;
      });

      _fitMarkersOnMap();
    }
  }

  void _fitMarkersOnMap() {
    if (_mapController != null &&
        _pickupLocation != null &&
        _dropLocation != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLocation!.latitude < _dropLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropLocation!.latitude,
          _pickupLocation!.longitude < _dropLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropLocation!.longitude,
        ),
        northeast: LatLng(
          _pickupLocation!.latitude > _dropLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropLocation!.latitude,
          _pickupLocation!.longitude > _dropLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropLocation!.longitude,
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Section with Gradient Overlay
          Positioned.fill(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: _pickupLocation ?? LatLng(28.6139, 77.2090),
                    zoom: 15.0,
                  ),
                  markers: _markers,
                  polylines: _polylines, // Display the polylines
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: '''[
                    {
                      "featureType": "poi",
                      "elementType": "labels",
                      "stylers": [{"visibility": "off"}]
                    }
                  ]''',
                ),
                // Gradient overlay for better readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Loading indicator for route
                if (_isLoadingRoute)
                  Positioned(
                    top: 120.h,
                    right: 16.w,
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Finding route...',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Modern App Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 10.h,
                  left: 16.w,
                  right: 16.w,
                  bottom: 16.h,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24.r),
                    bottomRight: Radius.circular(24.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        onPressed: () => context.go('/rider-home'),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Book a Ride',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Find your perfect ride',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Sheet with Enhanced Design
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32.r),
                    topRight: Radius.circular(32.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: Offset(0, -10),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Container(
                      margin: EdgeInsets.only(top: 12.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Trip Route Section
                            _buildTripRouteSection(),

                            SizedBox(height: 24.h),

                            // Distance and Time Info
                            if (_distance > 0) _buildRouteInfo(),

                            SizedBox(height: 24.h),

                            // Vehicle Selection
                            _buildVehicleSelectionSection(),

                            // Fare Display
                            if (_estimatedFare > 0) ...[
                              SizedBox(height: 24.h),
                              _buildFareDisplay(),
                            ],

                            SizedBox(height: 32.h),

                            // Enhanced Book Button
                            _buildBookButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripRouteSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Pickup Location
          Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final result = await _selectLocationOnMap('pickup');
                    if (result != null) {
                      setState(() {
                        _pickupLocation = result;
                      });

                      // IMPROVED: Better location name fetching
                      final address = await Provider.of<LocationProvider>(
                        context,
                        listen: false,
                      ).getAddressFromCoordinates(result);

                      setState(() {
                        _pickupController.text = address ?? 'Selected Location';
                      });

                      _updateMap();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _pickupController.text.isEmpty
                                ? 'Select pickup location'
                                : _pickupController.text,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color:
                                  _pickupController.text.isEmpty
                                      ? Colors.grey[600]
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.my_location,
                          size: 20.sp,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Dotted Line
          Container(
            margin: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              children: [
                SizedBox(width: 6.w),
                Container(
                  width: 2.w,
                  height: 30.h,
                  child: CustomPaint(painter: DottedLinePainter()),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Container(height: 1.h, color: Colors.grey[300]),
                ),
              ],
            ),
          ),

          // Drop Location
          Row(
            children: [
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final result = await _selectLocationOnMap('drop');
                    if (result != null) {
                      setState(() {
                        _dropLocation = result;
                      });

                      // IMPROVED: Better location name fetching with loading state
                      setState(() {
                        _dropController.text = 'Getting location name...';
                      });

                      final address = await Provider.of<LocationProvider>(
                        context,
                        listen: false,
                      ).getAddressFromCoordinates(result);

                      setState(() {
                        _dropController.text = address ?? 'Selected Location';
                      });

                      _updateMap();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dropController.text.isEmpty
                                ? 'Select drop location'
                                : _dropController.text,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color:
                                  _dropController.text.isEmpty
                                      ? Colors.grey[600]
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(Icons.location_on, size: 20.sp, color: Colors.red),
                      ],
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

  // Enhanced route info showing both distance and time
  Widget _buildRouteInfo() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Distance info
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.straighten,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distance',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${(_distance / 1000).toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(
            width: 1.w,
            height: 40.h,
            color: Colors.grey[300],
            margin: EdgeInsets.symmetric(horizontal: 16.w),
          ),

          // Time info
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Est. Time',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      _estimatedTime,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_car, color: AppColors.primary, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              'Choose Your Ride',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildEnhancedVehicleCard(
                VehicleType.auto,
                'Auto',
                Icons.directions_car,
                '₹30 base + ₹12/km',
                'Perfect for solo rides',
                Colors.orange,
              ),
              SizedBox(width: 12.w),
              _buildEnhancedVehicleCard(
                VehicleType.car,
                'Car',
                Icons.car_rental,
                '₹50 base + ₹15/km',
                'Comfortable & safe',
                Colors.blue,
              ),
              SizedBox(width: 12.w),
              _buildEnhancedVehicleCard(
                VehicleType.van,
                'Van',
                Icons.airport_shuttle,
                '₹80 base + ₹20/km',
                'Spacious for groups',
                Colors.purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedVehicleCard(
    VehicleType type,
    String name,
    IconData icon,
    String pricing,
    String description,
    Color accentColor,
  ) {
    final isSelected = _selectedVehicleType == type;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedVehicleType = type;
          });
          // Recalculate fare when vehicle type changes
          if (_distance > 0) {
            final rideProvider = Provider.of<RideProvider>(
              context,
              listen: false,
            );
            _estimatedFare = rideProvider.calculateFare(
              _distance,
              _selectedVehicleType,
            );
            setState(() {});
          }
        },
        child: Container(
          width: 140.w,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? accentColor : Colors.grey[300]!,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  icon,
                  size: 28.sp,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? accentColor : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                pricing,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? accentColor : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareDisplay() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estimated Fare',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '₹${_estimatedFare.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (_estimatedTime.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  'ETA: $_estimatedTime',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 24.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton() {
    return Consumer<RideProvider>(
      builder: (context, rideProvider, child) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            onPressed:
                _canBookRide() && !rideProvider.isLoading ? _bookRide : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: _canBookRide() ? 8 : 0,
              shadowColor: AppColors.primary.withOpacity(0.3),
            ),
            child:
                rideProvider.isLoading
                    ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Booking Ride...',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_taxi, size: 20.sp),
                        SizedBox(width: 8.w),
                        Text(
                          'Book Ride Now',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }

  bool _canBookRide() {
    return _pickupLocation != null &&
        _dropLocation != null &&
        _pickupController.text.isNotEmpty &&
        _dropController.text.isNotEmpty &&
        !_isLoadingRoute;
  }

  Future<void> _bookRide() async {
    if (!_canBookRide()) return;

    final authProvider = Provider.of<SimpleAuthProvider>(
      context,
      listen: false,
    );
    final rideProvider = Provider.of<RideProvider>(context, listen: false);

    final user = authProvider.currentUser!;

    final success = await rideProvider.requestRide(
      rider: user,
      pickupLocation: _pickupLocation!,
      dropLocation: _dropLocation!,
      pickupAddress: _pickupController.text,
      dropAddress: _dropController.text,
      vehicleType: _selectedVehicleType,
      distance: _distance,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(
                child: Text('Ride requested successfully! Finding a driver...'),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
      context.go('/rider-home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(rideProvider.errorMessage ?? 'Failed to book ride'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      );
    }
  }

  Future<LatLng?> _selectLocationOnMap(String type) async {
    return showDialog<LatLng>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        type == 'pickup'
                            ? Icons.my_location
                            : Icons.location_on,
                        color: type == 'pickup' ? Colors.green : Colors.red,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Select ${type == 'pickup' ? 'Pickup' : 'Drop'} Location',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, size: 20.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    height: 300.h,
                    width: double.maxFinite,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: GoogleMap(
                      onMapCreated: (GoogleMapController controller) {},
                      initialCameraPosition: CameraPosition(
                        target: _pickupLocation ?? LatLng(28.6139, 77.2090),
                        zoom: 15.0,
                      ),
                      onTap: (LatLng location) {
                        Navigator.pop(context, location);
                      },
                      markers: {
                        Marker(
                          markerId: MarkerId('selected'),
                          position: _pickupLocation ?? LatLng(28.6139, 77.2090),
                        ),
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.sp,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Tap on the map to select location',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}

// Custom painter for dotted line
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey[400]!
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
