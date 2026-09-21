import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationValidationService {
  static const double REQUIRED_RADIUS_METERS = 10.0;
  static const double MAXIMUM_GPS_ACCURACY_METERS = 10.0;
  static const int REQUIRED_DWELL_SECONDS = 15;
  static const int MAXIMUM_DWELL_SECONDS = 20;
  static const int MAXIMUM_LOCATION_AGE_SECONDS = 10;
  static const int REQUIRED_VALID_READINGS = 3;
  static const LocationAccuracy REQUIRED_LOCATION_ACCURACY = LocationAccuracy.best;

  static bool isPositionCurrentAndAccurate(Position position) {
    final age = DateTime.now().difference(position.timestamp).inSeconds;
    return position.accuracy <= MAXIMUM_GPS_ACCURACY_METERS &&
        age <= MAXIMUM_LOCATION_AGE_SECONDS;
  }
  
  /// Get job coordinates from multiple possible sources
  static Future<Map<String, dynamic>?> getJobCoordinates(Map<String, dynamic> job) async {
    print('🔍 Searching for job coordinates...');
    print('Job ID: ${job['_id']}');
    print('Job data structure: ${job.keys.toList()}');
    
    // Method 1: Try location field first (most reliable for bulk uploads)
    if (job['location'] != null) {
      final location = job['location'];
      print('📍 Location data: $location');
      
      // Handle both Map and direct object access
      dynamic lat = location is Map ? location['latitude'] : (location as dynamic).latitude;
      dynamic lng = location is Map ? location['longitude'] : (location as dynamic).longitude;
      
      if (lat != null && lng != null) {
        print('✅ Found coordinates in location: $lat, $lng');
        return {
          'latitude': (lat is num) ? lat.toDouble() : double.parse(lat.toString()),
          'longitude': (lng is num) ? lng.toDouble() : double.parse(lng.toString()),
          'source': 'location'
        };
      }
    }
    
    // Method 2: Try address coordinates
    if (job['address'] != null) {
      final address = job['address'];
      print('🏠 Address data: $address');
      
      // Handle both Map and direct object access
      dynamic lat = address is Map ? address['latitude'] : (address as dynamic).latitude;
      dynamic lng = address is Map ? address['longitude'] : (address as dynamic).longitude;
      
      if (lat != null && lng != null) {
        print('✅ Found coordinates in address: $lat, $lng');
        return {
          'latitude': (lat is num) ? lat.toDouble() : double.parse(lat.toString()),
          'longitude': (lng is num) ? lng.toDouble() : double.parse(lng.toString()),
          'source': 'address'
        };
      }
    }
    
    // Method 3: Try house coordinates
    if (job['house'] != null) {
      final house = job['house'];
      print('🏠 House data: $house');
      
      // Handle both Map and direct object access
      dynamic lat = house is Map ? house['latitude'] : (house as dynamic).latitude;
      dynamic lng = house is Map ? house['longitude'] : (house as dynamic).longitude;
      
      if (lat != null && lng != null) {
        print('✅ Found coordinates in house: $lat, $lng');
        return {
          'latitude': (lat is num) ? lat.toDouble() : double.parse(lat.toString()),
          'longitude': (lng is num) ? lng.toDouble() : double.parse(lng.toString()),
          'source': 'house'
        };
      }
    }
    
    // Method 4: Try to get coordinates from address string using geocoding
    String? addressString = buildAddressString(job);
    if (addressString != null) {
      print('🌍 Trying geocoding for address: $addressString');
      try {
        List<Location> locations = await locationFromAddress(addressString);
        if (locations.isNotEmpty) {
          final location = locations.first;
          print('✅ Found coordinates via geocoding: ${location.latitude}, ${location.longitude}');
          return {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'source': 'geocoding'
          };
        }
      } catch (e) {
        print('❌ Geocoding failed: $e');
      }
    }
    
    print('❌ No coordinates found for job');
    return null;
  }
  
  /// Build address string from job data
  static String? buildAddressString(Map<String, dynamic> job) {
    List<String> addressParts = [];
    
    // Try house address first
    if (job['house'] != null) {
      final house = job['house'];
      if (house['address'] != null) addressParts.add(house['address']);
      if (house['city'] != null) addressParts.add(house['city']);
      if (house['county'] != null) addressParts.add(house['county']);
      if (house['postcode'] != null) addressParts.add(house['postcode']);
    }
    
    // If no house address, try job address
    if (addressParts.isEmpty && job['address'] != null) {
      final address = job['address'];
      if (address['street'] != null) addressParts.add(address['street']);
      if (address['city'] != null) addressParts.add(address['city']);
      if (address['state'] != null) addressParts.add(address['state']);
      if (address['zipCode'] != null) addressParts.add(address['zipCode']);
    }
    
    return addressParts.isNotEmpty ? addressParts.join(', ') : null;
  }
  
  /// Calculate distance between two points
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
  
  /// Check if user is within required radius of job location
  static Future<Map<String, dynamic>> validateLocation(
    Position userPosition,
    Map<String, dynamic> job,
  ) async {
    print('🔍 Validating location for job: ${job['_id']}');
    print('👤 User position: ${userPosition.latitude}, ${userPosition.longitude}');
    
    // Get job coordinates
    final jobCoords = await getJobCoordinates(job);
    
    if (jobCoords == null) {
      return {
        'isValid': false,
        'distance': 0.0,
        'error': 'Job location coordinates not found',
        'canProceed': false,
      };
    }
    
    // Calculate distance
    final distance = calculateDistance(
      userPosition.latitude,
      userPosition.longitude,
      jobCoords['latitude']!,
      jobCoords['longitude']!,
    );
    
    final isValid = distance <= REQUIRED_RADIUS_METERS;
    
    print('📏 Distance: ${distance.toStringAsFixed(2)}m');
    print('✅ Within radius: $isValid');
    
    return {
      'isValid': isValid,
      'distance': distance,
      'jobCoordinates': jobCoords,
      'canProceed': isValid,
      'message': isValid 
          ? 'You are within the required ${REQUIRED_RADIUS_METERS}m radius'
          : 'You are ${distance.toStringAsFixed(0)}m away. Please move within ${REQUIRED_RADIUS_METERS}m to proceed.',
    };
  }
  
  /// Get current user position with error handling and improved accuracy
  static Future<Position?> getCurrentPosition() async {
    try {
      print('📍 Getting current position with high accuracy...');
      
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return null;
      }
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return null;
      }
      
      // Get position with best accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: REQUIRED_LOCATION_ACCURACY,
        timeLimit: const Duration(seconds: 15), // Increased timeout for better accuracy
      );
      
      print('✅ Current position: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      
      // If accuracy is outside the validation limit, try once more for a usable reading.
      if (position.accuracy > MAXIMUM_GPS_ACCURACY_METERS ||
          DateTime.now().difference(position.timestamp).inSeconds > MAXIMUM_LOCATION_AGE_SECONDS) {
        print('⚠️ Position does not meet the ${MAXIMUM_GPS_ACCURACY_METERS}m accuracy or ${MAXIMUM_LOCATION_AGE_SECONDS}s age limit, attempting to get a better reading...');
        // Wait a moment and try again
        await Future.delayed(const Duration(seconds: 2));
        Position betterPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: REQUIRED_LOCATION_ACCURACY,
          timeLimit: const Duration(seconds: 15),
        );
        if (isPositionCurrentAndAccurate(betterPosition)) {
          print('✅ Better position obtained: ${betterPosition.accuracy}m accuracy');
          return betterPosition;
        }
      }
      
      return isPositionCurrentAndAccurate(position) ? position : null;
      
    } catch (e) {
      print('❌ Error getting current position: $e');
      return null;
    }
  }
  
  /// Manual location input fallback
  static Future<Map<String, dynamic>?> getManualLocation() async {
    // This would be called from a dialog where user can input coordinates manually
    // For now, return null - this can be implemented with a dialog
    return null;
  }
}
