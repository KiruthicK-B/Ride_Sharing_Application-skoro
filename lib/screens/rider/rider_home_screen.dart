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

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer3<SimpleAuthProvider, LocationProvider, RideProvider>(
        builder:
            (context, authProvider, locationProvider, rideProvider, child) {
              final user = authProvider.currentUser;

              if (user == null) {
                return Center(child: CircularProgressIndicator());
              }

              return Stack(
                children: [
                  // Google Maps
                  GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      locationProvider.setMapController(controller);
                    },
                    initialCameraPosition: CameraPosition(
                      target: locationProvider.currentPosition != null
                          ? LatLng(
                              locationProvider.currentPosition!.latitude,
                              locationProvider.currentPosition!.longitude,
                            )
                          : LatLng(28.6139, 77.2090), // Default to Delhi
                      zoom: 15.0,
                    ),
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),

                  // Top App Bar
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
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
                                child: CircleAvatar(
                                  radius: 20.r,
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
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
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (locationProvider.currentAddress != null)
                                      Text(
                                        locationProvider.currentAddress!,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),

                              // Notification Icon
                              IconButton(
                                onPressed: () {
                                  // Show notifications
                                },
                                icon: Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Sheet
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20.r),
                          topRight: Radius.circular(20.r),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Padding(
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
                                if (snapshot.hasData && snapshot.data != null) {
                                  return _buildCurrentRideCard(
                                    snapshot.data!,
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
                  ),

                  // My Location Button
                  Positioned(
                    bottom: 280.h,
                    right: 16.w,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _getCurrentLocation,
                      backgroundColor: Colors.white,
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_taxi, color: AppColors.primary, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                'Current Ride',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(ride.status),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _getStatusText(ride.status),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Pickup and Drop locations
          Row(
            children: [
              Icon(Icons.my_location, color: AppColors.success, size: 16.sp),
              SizedBox(width: 8.w),
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
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.location_on, color: AppColors.error, size: 16.sp),
              SizedBox(width: 8.w),
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

          SizedBox(height: 12.h),

          // Driver info and fare
          if (ride.driverName != null) ...[
            Text(
              'Driver: ${ride.driverName}',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textPrimary),
            ),
            if (ride.driverPhone != null)
              Text(
                'Phone: ${ride.driverPhone}',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
          ] else ...[
            Text(
              'Searching for driver...',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
            ),
          ],

          Text(
            'Vehicle: ${ride.vehicleType.toString().split('.').last.toUpperCase()}',
            style: TextStyle(fontSize: 14.sp, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fare: ₹${ride.fare.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),

              // Cancel button (only show if ride hasn't started)
              if (ride.status == RideStatus.requested ||
                  ride.status == RideStatus.accepted)
                TextButton(
                  onPressed: () => _showCancelRideDialog(ride, rideProvider),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                  ),
                  child: Text(
                    'Cancel Ride',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookRideSection() {
    return Column(
      children: [
        Text(
          'Where would you like to go?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 16.h),
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
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24.sp, color: AppColors.primary),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(fontSize: 12.sp, color: AppColors.textPrimary),
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
        // TODO: Handle this case.
        throw UnimplementedError();
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
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: EdgeInsets.all(20.w),
          child: Column(
            children: [
              Text(
                'My Rides',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: Consumer<RideProvider>(
                  builder: (context, rideProvider, child) {
                    if (rideProvider.isLoading) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (rideProvider.riderRides.isEmpty) {
                      return Center(child: Text('No rides yet'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: rideProvider.riderRides.length,
                      itemBuilder: (context, index) {
                        final ride = rideProvider.riderRides[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8.h),
                          child: ListTile(
                            leading: Icon(Icons.local_taxi),
                            title: Text(ride.dropAddress),
                            subtitle: Text(
                              '₹${ride.fare.toStringAsFixed(0)} • ${ride.requestedAt.day}/${ride.requestedAt.month}',
                            ),
                            trailing: Text(_getStatusText(ride.status)),
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
      builder: (context) => AlertDialog(
        title: Text('Cancel Ride'),
        content: Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
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
                    content: Text('Ride cancelled successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      rideProvider.errorMessage ?? 'Failed to cancel ride',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text(
              'Yes, Cancel',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
