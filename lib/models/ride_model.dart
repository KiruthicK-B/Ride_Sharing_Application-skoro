import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RideStatus {
  requested,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled,
  arrived,
}

enum VehicleType { car, auto, van }

class RideModel {
  final String id;
  final String riderId;
  final String? driverId;
  final String riderName;
  final String riderPhone;
  final String? driverName;
  final String? driverPhone;
  final LatLng pickupLocation;
  final LatLng dropLocation;
  final String pickupAddress;
  final String dropAddress;
  final VehicleType vehicleType;
  final double fare;
  final RideStatus status;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final double? rating;
  final String? feedback;
  final LatLng? driverLocation;
  final DateTime? lastLocationUpdate;

  RideModel({
    required this.id,
    required this.riderId,
    this.driverId,
    required this.riderName,
    required this.riderPhone,
    this.driverName,
    this.driverPhone,
    required this.pickupLocation,
    required this.dropLocation,
    required this.pickupAddress,
    required this.dropAddress,
    required this.vehicleType,
    required this.fare,
    required this.status,
    required this.requestedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancellationReason,
    this.cancelledBy,
    this.rating,
    this.feedback,
    this.driverLocation,
    this.lastLocationUpdate,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] ?? '',
      riderId: json['riderId'] ?? '',
      driverId: json['driverId'],
      riderName: json['riderName'] ?? '',
      riderPhone: json['riderPhone'] ?? '',
      driverName: json['driverName'],
      driverPhone: json['driverPhone'],
      pickupLocation: LatLng(
        json['pickupLocation']['latitude'] ?? 0.0,
        json['pickupLocation']['longitude'] ?? 0.0,
      ),
      dropLocation: LatLng(
        json['dropLocation']['latitude'] ?? 0.0,
        json['dropLocation']['longitude'] ?? 0.0,
      ),
      pickupAddress: json['pickupAddress'] ?? '',
      dropAddress: json['dropAddress'] ?? '',
      vehicleType: VehicleType.values.firstWhere(
        (type) => type.toString() == json['vehicleType'],
        orElse: () => VehicleType.car,
      ),
      fare: (json['fare'] ?? 0.0).toDouble(),
      status: RideStatus.values.firstWhere(
        (status) => status.toString() == json['status'],
        orElse: () => RideStatus.requested,
      ),
      requestedAt: DateTime.parse(
        json['requestedAt'] ?? DateTime.now().toIso8601String(),
      ),
      acceptedAt:
          json['acceptedAt'] != null
              ? DateTime.parse(json['acceptedAt'])
              : null,
      startedAt:
          json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
      cancellationReason: json['cancellationReason'],
      cancelledBy: json['cancelledBy'],
      rating: json['rating']?.toDouble(),
      feedback: json['feedback'],
      driverLocation:
          json['driverLocation'] != null
              ? LatLng(
                json['driverLocation']['latitude'] ?? 0.0,
                json['driverLocation']['longitude'] ?? 0.0,
              )
              : null,
      lastLocationUpdate:
          json['lastLocationUpdate'] != null
              ? DateTime.parse(json['lastLocationUpdate'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'riderId': riderId,
      'driverId': driverId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'pickupLocation': {
        'latitude': pickupLocation.latitude,
        'longitude': pickupLocation.longitude,
      },
      'dropLocation': {
        'latitude': dropLocation.latitude,
        'longitude': dropLocation.longitude,
      },
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      'vehicleType': vehicleType.toString(),
      'fare': fare,
      'status': status.toString(),
      'requestedAt': requestedAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'rating': rating,
      'feedback': feedback,
      'driverLocation':
          driverLocation != null
              ? {
                'latitude': driverLocation!.latitude,
                'longitude': driverLocation!.longitude,
              }
              : null,
      'lastLocationUpdate': lastLocationUpdate?.toIso8601String(),
    };
  }

  RideModel copyWith({
    String? id,
    String? riderId,
    String? driverId,
    String? riderName,
    String? riderPhone,
    String? driverName,
    String? driverPhone,
    LatLng? pickupLocation,
    LatLng? dropLocation,
    String? pickupAddress,
    String? dropAddress,
    VehicleType? vehicleType,
    double? fare,
    RideStatus? status,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? cancellationReason,
    String? cancelledBy,
    double? rating,
    String? feedback,
    LatLng? driverLocation,
    DateTime? lastLocationUpdate,
  }) {
    return RideModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      driverId: driverId ?? this.driverId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropLocation: dropLocation ?? this.dropLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropAddress: dropAddress ?? this.dropAddress,
      vehicleType: vehicleType ?? this.vehicleType,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      rating: rating ?? this.rating,
      feedback: feedback ?? this.feedback,
      driverLocation: driverLocation ?? this.driverLocation,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }
}
