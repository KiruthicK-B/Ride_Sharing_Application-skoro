import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ride_model.dart';
import '../models/user_model.dart';

class RideProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  List<RideModel> _riderRides = [];
  List<RideModel> _driverRides = [];
  List<RideModel> _availableRides = [];
  RideModel? _currentRide;
  bool _isLoading = false;
  String? _errorMessage;

  List<RideModel> get riderRides => _riderRides;
  List<RideModel> get driverRides => _driverRides;
  List<RideModel> get availableRides => _availableRides;
  RideModel? get currentRide => _currentRide;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Fare calculation based on distance and vehicle type
  double calculateFare(double distanceInMeters, VehicleType vehicleType) {
    double distanceInKm = distanceInMeters / 1000;
    double baseFare;
    double perKmRate;

    switch (vehicleType) {
      case VehicleType.auto:
        baseFare = 30.0;
        perKmRate = 12.0;
        break;
      case VehicleType.car:
        baseFare = 50.0;
        perKmRate = 15.0;
        break;
      case VehicleType.van:
        baseFare = 80.0;
        perKmRate = 20.0;
        break;
    }

    return baseFare + (distanceInKm * perKmRate);
  }

  Future<bool> requestRide({
    required UserModel rider,
    required LatLng pickupLocation,
    required LatLng dropLocation,
    required String pickupAddress,
    required String dropAddress,
    required VehicleType vehicleType,
    required double distance,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final rideId = _uuid.v4();
      final fare = calculateFare(distance, vehicleType);

      final ride = RideModel(
        id: rideId,
        riderId: rider.id,
        riderName: rider.name,
        riderPhone: rider.phone,
        pickupLocation: pickupLocation,
        dropLocation: dropLocation,
        pickupAddress: pickupAddress,
        dropAddress: dropAddress,
        vehicleType: vehicleType,
        fare: fare,
        status: RideStatus.requested,
        requestedAt: DateTime.now(),
      );

      await _firestore.collection('rides').doc(rideId).set(ride.toJson());

      _currentRide = ride;
      _riderRides.insert(0, ride);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to request ride: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptRide(String rideId, UserModel driver) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('rides').doc(rideId).update({
        'driverId': driver.id,
        'driverName': driver.name,
        'driverPhone': driver.phone,
        'status': RideStatus.accepted.toString(),
        'acceptedAt': DateTime.now().toIso8601String(),
      });

      // Update local state
      _availableRides.removeWhere((ride) => ride.id == rideId);

      final updatedRide = await _getRideById(rideId);
      if (updatedRide != null) {
        _currentRide = updatedRide;
        _driverRides.insert(0, updatedRide);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to accept ride: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRideStatus(String rideId, RideStatus status) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final updateData = {'status': status.toString()};

      switch (status) {
        case RideStatus.driverArriving:
          // No additional data needed
          break;
        case RideStatus.inProgress:
          updateData['startedAt'] = DateTime.now().toIso8601String();
          break;
        case RideStatus.completed:
          updateData['completedAt'] = DateTime.now().toIso8601String();
          break;
        case RideStatus.cancelled:
          updateData['completedAt'] = DateTime.now().toIso8601String();
          break;
        default:
          break;
      }

      await _firestore.collection('rides').doc(rideId).update(updateData);

      // Update local state
      final updatedRide = await _getRideById(rideId);
      if (updatedRide != null) {
        _currentRide = updatedRide;

        // Update in rider rides
        final riderIndex = _riderRides.indexWhere((ride) => ride.id == rideId);
        if (riderIndex != -1) {
          _riderRides[riderIndex] = updatedRide;
        }

        // Update in driver rides
        final driverIndex = _driverRides.indexWhere(
          (ride) => ride.id == rideId,
        );
        if (driverIndex != -1) {
          _driverRides[driverIndex] = updatedRide;
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update ride status: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadRiderRides(String riderId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('rides')
          .where('riderId', isEqualTo: riderId)
          .get();

      _riderRides = snapshot.docs
          .map((doc) => RideModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      // Sort by requestedAt in memory (most recent first)
      _riderRides.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load rides: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDriverRides(String driverId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .get();

      _driverRides = snapshot.docs
          .map((doc) => RideModel.fromJson({'id': doc.id, ...doc.data()}))
          .toList();

      // Sort by requestedAt in memory (most recent first)
      _driverRides.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load rides: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get available rides stream for drivers (only active rides)
  Stream<List<RideModel>> getAvailableRidesStream() {
    return _firestore
        .collection('rides')
        .where('status', isEqualTo: RideStatus.requested.toString())
        .limit(20) // Limit to 20 most recent rides
        .snapshots()
        .map((snapshot) {
          print(
            'Available rides snapshot: ${snapshot.docs.length} rides found',
          );
          _availableRides = snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  print('Processing ride: ${doc.id} with data: $data');
                  return RideModel.fromJson({'id': doc.id, ...data});
                } catch (e) {
                  print('Error parsing ride ${doc.id}: $e');
                  return null;
                }
              })
              .where((ride) => ride != null)
              .cast<RideModel>()
              .toList();

          // Sort by requestedAt in memory (most recent first)
          _availableRides.sort(
            (a, b) => b.requestedAt.compareTo(a.requestedAt),
          );

          print('Processed ${_availableRides.length} valid rides');
          notifyListeners();
          return _availableRides;
        });
  }

  // Get current ride stream for a specific user
  Stream<RideModel?> getCurrentRideStream(String userId) {
    return _firestore
        .collection('rides')
        .where('riderId', isEqualTo: userId)
        .where(
          'status',
          whereIn: [
            RideStatus.requested.toString(),
            RideStatus.accepted.toString(),
            RideStatus.driverArriving.toString(),
            RideStatus.inProgress.toString(),
          ],
        )
        .limit(5) // Get a few more to sort in memory
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            // Sort in memory and get the most recent one
            final rides = snapshot.docs
                .map((doc) => RideModel.fromJson({'id': doc.id, ...doc.data()}))
                .toList();
            rides.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
            _currentRide = rides.first;
            notifyListeners();
            return _currentRide;
          } else {
            _currentRide = null;
            notifyListeners();
            return null;
          }
        });
  }

  // Get driver's current ride stream
  Stream<RideModel?> getDriverCurrentRideStream(String driverId) {
    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .where(
          'status',
          whereIn: [
            RideStatus.accepted.toString(),
            RideStatus.driverArriving.toString(),
            RideStatus.inProgress.toString(),
          ],
        )
        .limit(5) // Get a few more to sort in memory
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            // Sort in memory and get the most recent one
            final rides = snapshot.docs
                .map((doc) => RideModel.fromJson({'id': doc.id, ...doc.data()}))
                .toList();
            rides.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
            _currentRide = rides.first;
            notifyListeners();
            return _currentRide;
          } else {
            _currentRide = null;
            notifyListeners();
            return null;
          }
        });
  }

  // Cancel ride (for both rider and driver)
  Future<bool> cancelRide(
    String rideId,
    String cancelledBy, {
    String? reason,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _firestore.collection('rides').doc(rideId).update({
        'status': RideStatus.cancelled.toString(),
        'cancellationReason': reason ?? 'Cancelled by $cancelledBy',
        'cancelledBy': cancelledBy,
        'completedAt': DateTime.now().toIso8601String(),
      });

      // Clear current ride if it's the one being cancelled
      if (_currentRide?.id == rideId) {
        _currentRide = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to cancel ride: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<RideModel?> _getRideById(String rideId) async {
    try {
      final doc = await _firestore.collection('rides').doc(rideId).get();
      if (doc.exists) {
        return RideModel.fromJson({'id': doc.id, ...doc.data()!});
      }
    } catch (e) {
      _errorMessage = 'Failed to get ride: $e';
      notifyListeners();
    }
    return null;
  }

  Future<bool> rateRide(String rideId, double rating, String feedback) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'rating': rating,
        'feedback': feedback,
      });

      // Update local ride
      final rideIndex = _riderRides.indexWhere((ride) => ride.id == rideId);
      if (rideIndex != -1) {
        _riderRides[rideIndex] = _riderRides[rideIndex].copyWith(
          rating: rating,
          feedback: feedback,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to rate ride: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearCurrentRide() {
    _currentRide = null;
    notifyListeners();
  }

  // Method to clean up test rides from Firebase
  Future<void> cleanupTestRides() async {
    try {
      // First, get all rides and filter in memory to avoid index requirements
      final snapshot = await _firestore.collection('rides').get();

      final batch = _firestore.batch();
      int deletedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final riderId = data['riderId'] as String?;

        // Check if this is a test ride
        if (riderId != null && riderId.startsWith('test_rider_')) {
          batch.delete(doc.reference);
          print('Deleting test ride: ${doc.id} - ${data['riderName']}');
          deletedCount++;
        }
      }

      if (deletedCount > 0) {
        await batch.commit();
        print('Deleted $deletedCount test rides');
      } else {
        print('No test rides found to delete');
      }
    } catch (e) {
      print('Error cleaning up test rides: $e');
    }
  }
}
