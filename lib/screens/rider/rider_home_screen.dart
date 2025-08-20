import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/simple_auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/ride_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../models/ride_model.dart';
// ignore: unused_import
import 'dart:math' as Math;

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  RideModel? _currentRide;
  String? _currentRouteId; // Track current route to prevent unnecessary updates

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  Future<void> _getCurrentLocation() async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    await locationProvider.getCurrentLocation();

    if (locationProvider.currentPosition != null) {
      _updateMapLocation(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
      );
    }
  }

  void _updateMapLocation(double latitude, double longitude) {
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId('current_location'),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      };
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(latitude, longitude), zoom: 15.0),
        ),
      );
    }
  }

  // IMPROVED: Better ride map update with route caching
  void _updateMapWithRide(RideModel? ride) {
    if (ride == null) {
      setState(() {
        _markers.clear();
        _polylines.clear();
        _currentRide = null;
        _currentRouteId = null;
      });
      _getCurrentLocation();
      return;
    }

    // Only update if ride has changed
    if (_currentRide?.id == ride.id &&
        _currentRide?.status == ride.status &&
        _currentRouteId != null) {
      return;
    }

    _currentRide = ride;
    _updateRideMarkersAndRoute(ride);
  }

  // IMPROVED: Better route handling with stable polylines
  Future<void> _updateRideMarkersAndRoute(RideModel ride) async {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    // Create unique route ID
    final String newRouteId = '${ride.id}_${ride.status.toString()}';

    // Don't reload if it's the same route
    if (_currentRouteId == newRouteId) {
      return;
    }

    setState(() {
      _markers.clear();

      // Add pickup marker
      _markers.add(
        Marker(
          markerId: MarkerId('pickup'),
          position: ride.pickupLocation,
          infoWindow: InfoWindow(
            title: 'Pickup Location',
            snippet: ride.pickupAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      // Add drop marker
      _markers.add(
        Marker(
          markerId: MarkerId('drop'),
          position: ride.dropLocation,
          infoWindow: InfoWindow(
            title: 'Drop Location',
            snippet: ride.dropAddress,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      // Add driver location marker if available (for accepted/in-progress rides)
      if (ride.status != RideStatus.requested &&
          ride.status != RideStatus.cancelled &&
          ride.status != RideStatus.completed) {
        // You might need to add driver location to your ride model
        // For now, we'll use pickup location as a placeholder
        _markers.add(
          Marker(
            markerId: MarkerId('driver'),
            position:
                ride.pickupLocation, // Replace with actual driver location
            infoWindow: InfoWindow(
              title: 'Driver',
              snippet: ride.driverName ?? 'Driver on the way',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueYellow,
            ),
          ),
        );
      }
    });

    // Get and display the route
    try {
      final directions = await locationProvider.getDirections(
        origin: ride.pickupLocation,
        destination: ride.dropLocation,
      );

      if (directions != null) {
        final polyline = directions.toPolyline(
          polylineId: 'ride_route_$newRouteId',
          color: _getRouteColorForStatus(ride.status),
          width: 6,
        );

        setState(() {
          // Remove old polylines and add new one
          _polylines.removeWhere(
            (p) => p.polylineId.value.startsWith('ride_route_'),
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
        // Fallback to simple route
        _createFallbackRoute(ride, newRouteId);
      }
    } catch (e) {
      print('Error getting directions for ride: $e');
      _createFallbackRoute(ride, newRouteId);
    }
  }

  void _createFallbackRoute(RideModel ride, String routeId) {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );

    final fallbackPoints = locationProvider.createSimpleRoutePolyline(
      ride.pickupLocation,
      ride.dropLocation,
    );

    final fallbackPolyline = Polyline(
      polylineId: PolylineId('ride_route_$routeId'),
      points: fallbackPoints,
      color: _getRouteColorForStatus(ride.status).withOpacity(0.7),
      width: 4,
      patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      geodesic: true,
    );

    setState(() {
      _polylines.removeWhere(
        (p) => p.polylineId.value.startsWith('ride_route_'),
      );
      _polylines.add(fallbackPolyline);
      _currentRouteId = routeId;
    });

    _fitMarkersOnMap(ride);
  }

  // Get route color based on ride status
  Color _getRouteColorForStatus(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.warning;
      case RideStatus.accepted:
        return AppColors.info;
      case RideStatus.driverArriving:
        return AppColors.primary;
      case RideStatus.inProgress:
        return AppColors.success;
      case RideStatus.completed:
        return AppColors.success;
      case RideStatus.cancelled:
        return AppColors.error;
      case RideStatus.arrived:
        return AppColors.primary;
    }
  }

  // Fit markers on map for ride view
  void _fitMarkersOnMap(RideModel ride) {
    if (_mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          ride.pickupLocation.latitude < ride.dropLocation.latitude
              ? ride.pickupLocation.latitude
              : ride.dropLocation.latitude,
          ride.pickupLocation.longitude < ride.dropLocation.longitude
              ? ride.pickupLocation.longitude
              : ride.dropLocation.longitude,
        ),
        northeast: LatLng(
          ride.pickupLocation.latitude > ride.dropLocation.latitude
              ? ride.pickupLocation.latitude
              : ride.dropLocation.latitude,
          ride.pickupLocation.longitude > ride.dropLocation.longitude
              ? ride.pickupLocation.longitude
              : ride.dropLocation.longitude,
        ),
      );

      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer3<SimpleAuthProvider, LocationProvider, RideProvider>(
        builder: (
          context,
          authProvider,
          locationProvider,
          rideProvider,
          child,
        ) {
          final user = authProvider.currentUser;

          if (user == null) {
            return Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              // Google Maps with enhanced display
              GoogleMap(
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  locationProvider.setMapController(controller);
                },
                initialCameraPosition: CameraPosition(
                  target:
                      locationProvider.currentPosition != null
                          ? LatLng(
                            locationProvider.currentPosition!.latitude,
                            locationProvider.currentPosition!.longitude,
                          )
                          : LatLng(28.6139, 77.2090), // Default to Delhi
                  zoom: 15.0,
                ),
                markers: _markers,
                polylines: _polylines, // Added polylines display
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

              // Top App Bar with enhanced design
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.9),
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
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          // Profile Avatar
                          GestureDetector(
                            onTap: _showProfileMenu,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              padding: EdgeInsets.all(2.w),
                              child: CircleAvatar(
                                radius: 18.r,
                                backgroundColor: Colors.white,
                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 12.w),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, ${user.name}',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (locationProvider.currentAddress != null)
                                  Text(
                                    locationProvider.currentAddress!,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),

                          // Notification Icon
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: IconButton(
                              onPressed: () {
                                // Show notifications
                              },
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Action Sheet with enhanced design
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
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
                          padding: EdgeInsets.all(20.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Current Ride Status or Book Ride Button
                              StreamBuilder<RideModel?>(
                                stream: rideProvider.getCurrentRideStream(
                                  user.id,
                                ),
                                builder: (context, snapshot) {
                                  final ride = snapshot.data;

                                  // Update map when ride changes - but only when needed
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (ride?.id != _currentRide?.id ||
                                        ride?.status != _currentRide?.status) {
                                      _updateMapWithRide(ride);
                                    }
                                  });

                                  if (snapshot.hasData && ride != null) {
                                    return _buildCurrentRideCard(
                                      ride,
                                      rideProvider,
                                    );
                                  } else {
                                    return _buildBookRideSection();
                                  }
                                },
                              ),

                              SizedBox(height: 16.h),

                              // Quick Actions
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickAction(
                                      icon: Icons.history,
                                      label: 'My Rides',
                                      onTap: () {
                                        _showRideHistory();
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: _buildQuickAction(
                                      icon: Icons.favorite,
                                      label: 'Saved Places',
                                      onTap: () {
                                        // Show saved places
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: _buildQuickAction(
                                      icon: Icons.support_agent,
                                      label: 'Support',
                                      onTap: () {
                                        // Show support
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // My Location Button
              Positioned(
                bottom: 280.h,
                right: 16.w,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.white,
                  elevation: 8,
                  child: Icon(Icons.my_location, color: AppColors.primary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentRideCard(RideModel ride, RideProvider rideProvider) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(ride.status).withOpacity(0.1),
            _getStatusColor(ride.status).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _getStatusColor(ride.status)),
        boxShadow: [
          BoxShadow(
            color: _getStatusColor(ride.status).withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: _getStatusColor(ride.status),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(Icons.local_taxi, color: Colors.white, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Ride',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(ride.status),
                      ),
                    ),
                    Text(
                      _getStatusDescription(ride.status),
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(ride.status),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  _getStatusText(ride.status),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Route Info
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                // Pickup
                Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        ride.pickupAddress,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Dotted line
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    children: [
                      SizedBox(width: 4.w),
                      Container(
                        width: 2.w,
                        height: 20.h,
                        child: CustomPaint(painter: DottedLinePainter()),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Container(height: 1.h, color: Colors.grey[300]),
                      ),
                    ],
                  ),
                ),

                // Drop
                Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        ride.dropAddress,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Driver info and ride details
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (ride.driverName != null) ...[
                      Text(
                        'Driver: ${ride.driverName}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (ride.driverPhone != null)
                        Text(
                          'Phone: ${ride.driverPhone}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ] else ...[
                      Text(
                        'Searching for driver...',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    Text(
                      'Vehicle: ${ride.vehicleType.toString().split('.').last.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Fare display
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _getStatusColor(ride.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'Fare',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹${ride.fare.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(ride.status),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action buttons
          if (ride.status == RideStatus.requested ||
              ride.status == RideStatus.accepted) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                if (ride.driverPhone != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Call driver functionality
                        // You can implement phone call here
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      icon: Icon(Icons.call, size: 16.sp),
                      label: Text('Call', style: TextStyle(fontSize: 14.sp)),
                    ),
                  ),
                if (ride.driverPhone != null) SizedBox(width: 12.w),
                Expanded(
                  child: TextButton(
                    onPressed: () => _showCancelRideDialog(ride, rideProvider),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        side: BorderSide(color: AppColors.error),
                      ),
                    ),
                    child: Text(
                      'Cancel Ride',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookRideSection() {
    return Column(
      children: [
        Icon(Icons.local_taxi, size: 48.sp, color: AppColors.primary),
        SizedBox(height: 16.h),
        Text(
          'Where would you like to go?',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8.h),
        Text(
          'Book a ride to your destination',
          style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
        CustomButton(
          text: 'Book a Ride',
          icon: Icons.search,
          onPressed: () {
            context.go('/book-ride');
          },
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, size: 20.sp, color: AppColors.primary),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return AppColors.warning;
      case RideStatus.accepted:
        return AppColors.info;
      case RideStatus.driverArriving:
        return AppColors.primary;
      case RideStatus.inProgress:
        return AppColors.success;
      case RideStatus.completed:
        return AppColors.success;
      case RideStatus.cancelled:
        return AppColors.error;
      case RideStatus.arrived:
        return AppColors.primary;
    }
  }

  String _getStatusText(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'Finding Driver';
      case RideStatus.accepted:
        return 'Driver Assigned';
      case RideStatus.driverArriving:
        return 'Driver Arriving';
      case RideStatus.inProgress:
        return 'On Trip';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
      case RideStatus.arrived:
        return 'Driver Arrived';
    }
  }

  String _getStatusDescription(RideStatus status) {
    switch (status) {
      case RideStatus.requested:
        return 'Looking for available drivers nearby';
      case RideStatus.accepted:
        return 'Driver is on the way to pickup';
      case RideStatus.driverArriving:
        return 'Driver will arrive soon';
      case RideStatus.inProgress:
        return 'Enjoy your ride safely';
      case RideStatus.completed:
        return 'Thank you for riding with us';
      case RideStatus.cancelled:
        return 'Ride was cancelled';
      case RideStatus.arrived:
        return 'Driver has arrived at pickup';
    }
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 20.h),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to profile
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.settings, color: AppColors.primary),
                  ),
                  title: Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to settings
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(Icons.logout, color: AppColors.error),
                  ),
                  title: Text('Sign Out'),
                  onTap: () {
                    Navigator.pop(context);
                    Provider.of<SimpleAuthProvider>(
                      context,
                      listen: false,
                    ).signOut();
                    context.go('/user-type');
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _showRideHistory() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final authProvider = Provider.of<SimpleAuthProvider>(
      context,
      listen: false,
    );

    rideProvider.loadRiderRides(authProvider.currentUser!.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            builder:
                (context, scrollController) => Container(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'My Rides',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Expanded(
                        child: Consumer<RideProvider>(
                          builder: (context, rideProvider, child) {
                            if (rideProvider.isLoading) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16.h),
                                    Text('Loading your rides...'),
                                  ],
                                ),
                              );
                            }

                            if (rideProvider.riderRides.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 64.sp,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No rides yet',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      'Your ride history will appear here',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: rideProvider.riderRides.length,
                              itemBuilder: (context, index) {
                                final ride = rideProvider.riderRides[index];
                                return Container(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  padding: EdgeInsets.all(16.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                ride.status,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Icon(
                                              Icons.local_taxi,
                                              size: 16.sp,
                                              color: _getStatusColor(
                                                ride.status,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${ride.requestedAt.day}/${ride.requestedAt.month}/${ride.requestedAt.year}',
                                                  style: TextStyle(
                                                    fontSize: 14.sp,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${ride.requestedAt.hour.toString().padLeft(2, '0')}:${ride.requestedAt.minute.toString().padLeft(2, '0')}',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                ride.status,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              _getStatusText(ride.status),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),

                                      // Route info
                                      Row(
                                        children: [
                                          Column(
                                            children: [
                                              Container(
                                                width: 8.w,
                                                height: 8.w,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              Container(
                                                width: 2.w,
                                                height: 20.h,
                                                color: Colors.grey[300],
                                              ),
                                              Container(
                                                width: 8.w,
                                                height: 8.w,
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  ride.pickupAddress,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.grey[700],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 8.h),
                                                Text(
                                                  ride.dropAddress,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    color: Colors.grey[700],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 12.h),

                                      // Fare and vehicle info
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${ride.fare.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Text(
                                            ride.vehicleType
                                                .toString()
                                                .split('.')
                                                .last
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _showCancelRideDialog(RideModel ride, RideProvider rideProvider) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Row(
              children: [
                Icon(Icons.warning, color: AppColors.error),
                SizedBox(width: 8.w),
                Text('Cancel Ride'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to cancel this ride?'),
                SizedBox(height: 8.h),
                Text(
                  'Cancellation charges may apply.',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Keep Ride',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final success = await rideProvider.cancelRide(
                    ride.id,
                    'rider',
                    reason: 'Cancelled by rider',
                  );

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8.w),
                            Text('Ride cancelled successfully'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.white),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                rideProvider.errorMessage ??
                                    'Failed to cancel ride',
                              ),
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
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: Text('Cancel Ride'),
              ),
            ],
          ),
    );
  }
}

// Custom painter for dotted line (reused from booking screen)
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
