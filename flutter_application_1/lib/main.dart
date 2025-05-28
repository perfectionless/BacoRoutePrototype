import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baco-Route',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A5F),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A5F),
          ),
        ),
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  int _currentIndex = 0;
  bool _showStops = true;
  List<String> _selectedRoutes = [];
  bool _isLoading = true;
  String _errorMessage = '';

  final LatLng _bacolodCityCenter = LatLng(10.6713, 122.9511);

  // Dynamic data from API
  List<RouteData> _allRoutes = [];
  List<TerminalData> _allTerminals = [];
  List<StopData> _allStops = [];

  // Route finder controllers
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  LatLng? _currentLocation;
  bool _isGettingLocation = false;
  List<RouteData> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadDataFromAPI();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      print('Error getting location: $e');
    }
  }
  Future<void> _loadDataFromAPI() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('=== Starting data load from API ===');
      
      // Load all data concurrently
      await Future.wait([
        _loadRoutes(),
        _loadTerminals(),
        _loadStops(),
      ]);

      print('=== Finished loading data ===');
      print('Routes loaded: ${_allRoutes.length}');
      for (var route in _allRoutes) {
        print('- ${route.name}: ${route.stops.length} stops');
      }
      print('Terminals loaded: ${_allTerminals.length}');
      print('Stops loaded: ${_allStops.length}');

      // Initialize route points after loading routes
      await _initializeRoutes();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }
  Future<void> _loadRoutes() async {
    print('Loading routes from API...');
    final routes = await ApiService.getRoutes();
    print('Received ${routes.length} routes from API');
    
    _allRoutes = routes;
    
    // Debug each route
    for (var route in _allRoutes) {
      print('Route: ${route.name} has ${route.stops.length} stops:');
      for (var stop in route.stops) {
        print('  - ${stop.name} at ${stop.location}');
      }
    }
  }

  Future<void> _loadTerminals() async {
    final terminals = await ApiService.getTerminals();
    _allTerminals = terminals;
  }

  Future<void> _loadStops() async {
    final stops = await ApiService.getStops();
    _allStops = stops;
  }

  Future<void> _initializeRoutes() async {
    for (final route in _allRoutes) {
      await route.fetchRoutePoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BACO-ROUTE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadDataFromAPI();
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () {
              _getCurrentLocation();
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
              }
            },
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading route data...'),
              ],
            ),
          )
        : _errorMessage.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error: $_errorMessage', textAlign: TextAlign.center),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _loadDataFromAPI(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _bacolodCityCenter,
                    initialZoom: 14.0,
                    minZoom: 12.0,
                    maxZoom: 18.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: _getSelectedRoutePolylines(),
                    ),
                    if (_showStops)
                      MarkerLayer(
                        markers: _getVisibleMarkers(),
                      ),
                  ],
                ),

                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.1,
                  maxChildSize: 0.8,
                  snapSizes: const [0.3, 0.6, 0.8],
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onVerticalDragUpdate: (_) {},
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              width: double.infinity,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: scrollController,
                              child: _buildCurrentView(scrollController),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E3A5F),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.place), label: 'Terminals'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Finder'),
        ],
      ),
    );
  }

  Widget _buildCurrentView(ScrollController scrollController) {
    switch (_currentIndex) {
      case 0:
        return _buildRoutesView();
      case 1:
        return _buildTerminalsView(scrollController);
      case 2:
        return _buildFinderView(scrollController);
      default:
        return Container();
    }
  }

  Widget _buildRoutesView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Select Routes', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedRoutes = _allRoutes.map((r) => r.name).toList();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Select All', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedRoutes.clear();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Clear', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        
        if (_allRoutes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'No routes available. Please add routes in the admin panel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          )
        else
          // Routes list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16),
            itemCount: _allRoutes.length,
            itemBuilder: (context, index) {
              final route = _allRoutes[index];
              final isSelected = _selectedRoutes.contains(route.name);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),                child: GestureDetector(
                  onLongPress: () {
                    // Show debug info on long press
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Route Debug: ${route.name}'),
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Route ID: ${route.id}'),
                            Text('Color: ${route.color}'),
                            Text('Points: ${route.points.length}'),
                            Text('Stops: ${route.stops.length}'),
                            if (route.stops.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Stop List:', style: TextStyle(fontWeight: FontWeight.bold)),
                              ...route.stops.map((stop) => Text('• ${stop.name}')),
                            ],
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: CheckboxListTile(
                    title: Text(route.name),
                    subtitle: Text('${route.stops.length} stops${route.stops.isEmpty ? ' - Long press for debug' : ''}'),
                    secondary: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: route.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value!) {
                          _selectedRoutes.add(route.name);
                        } else {
                          _selectedRoutes.remove(route.name);
                        }
                      });
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTerminalsView(ScrollController scrollController) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Terminals & Stops', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ),
              const Text('Show on map'),
              Switch(
                value: _showStops,
                onChanged: (value) {
                  setState(() {
                    _showStops = value;
                  });
                },
              ),
            ],
          ),
        ),
        
        // Terminals section
        if (_allTerminals.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Terminals', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _allTerminals.length,
            itemBuilder: (context, index) {
              final terminal = _allTerminals[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.location_city, color: Colors.red),
                  title: Text(terminal.name),
                  subtitle: terminal.description != null 
                    ? Text(terminal.description!) 
                    : null,
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    _mapController.move(terminal.location, 15.0);
                  },
                ),
              );
            },
          ),
        ],
        
        // Stops section - now shows all stops from routes
        if (_allStops.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Stops', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _allStops.length,
            itemBuilder: (context, index) {
              final stop = _allStops[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.directions_bus, color: Colors.blue),
                  title: Text(stop.name),
                  subtitle: stop.description != null 
                    ? Text(stop.description!) 
                    : null,
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    _mapController.move(stop.location, 15.0);
                  },
                ),
              );
            },
          ),
        ],

        // Show message if no data
        if (_allTerminals.isEmpty && _allStops.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'No terminals or stops found. Please add data in the admin panel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFinderView(ScrollController scrollController) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('Route Finder', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 16),
              
              // From location with current location button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _fromController,
                      decoration: InputDecoration(
                        labelText: 'From',
                        hintText: 'Enter starting location',
                        prefixIcon: const Icon(Icons.my_location),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isGettingLocation ? null : () async {
                      if (_currentLocation != null) {
                        final address = await _getAddressFromLocation(_currentLocation!);
                        _fromController.text = address;
                      } else {
                        await _getCurrentLocation();
                        if (_currentLocation != null) {
                          final address = await _getAddressFromLocation(_currentLocation!);
                          _fromController.text = address;
                        }
                      }
                    },
                    icon: _isGettingLocation 
                      ? const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        )
                      : const Icon(Icons.gps_fixed),
                    label: const Text('GPS'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // To location with dropdown suggestions
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  
                  // Combine all terminals and stops for suggestions
                  final allLocations = <String>[];
                  for (final terminal in _allTerminals) {
                    allLocations.add(terminal.name);
                  }
                  for (final stop in _allStops) {
                    allLocations.add(stop.name);
                  }
                  
                  return allLocations.where((String location) {
                    return location.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _toController.text = selection;
                },
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController fieldTextEditingController,
                  FocusNode fieldFocusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  _toController.text = fieldTextEditingController.text;
                  return TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: 'To',
                      hintText: 'Enter destination',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      _toController.text = value;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              
              ElevatedButton(
                onPressed: () {
                  _findRoutes();
                },
                child: const Text('Find Routes'),
              ),
            ],
          ),
        ),
        
        // Search results
        if (_searchResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Route Suggestions', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
            ),
          ),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final route = _searchResults[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: route.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(route.name),
                  subtitle: Text('${route.stops.length} stops'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    // Show route on map
                    setState(() {
                      _selectedRoutes = [route.name];
                      _currentIndex = 0; // Switch to routes tab
                    });
                    
                    // Fit map to route bounds
                    if (route.stops.isNotEmpty) {
                      final bounds = _calculateBounds(route.stops.map((s) => s.location).toList());
                      _mapController.fitCamera(CameraFit.bounds(bounds: bounds));
                    }
                  },
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _findRoutes() {
    if (_fromController.text.isEmpty || _toController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both from and to locations')),
      );
      return;
    }

    // Simple route finding logic
    // Find routes that contain stops near the from/to locations
    final results = <RouteData>[];
    final fromText = _fromController.text.toLowerCase();
    final toText = _toController.text.toLowerCase();

    for (final route in _allRoutes) {
      bool hasFrom = false;
      bool hasTo = false;
      
      for (final stop in route.stops) {
        if (stop.name.toLowerCase().contains(fromText)) {
          hasFrom = true;
        }
        if (stop.name.toLowerCase().contains(toText)) {
          hasTo = true;
        }
      }
      
      if (hasFrom && hasTo) {
        results.add(route);
      }
    }

    setState(() {
      _searchResults = results;
    });

    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No direct routes found between these locations')),
      );
    }
  }

  Future<String> _getAddressFromLocation(LatLng location) async {
    // This is a placeholder - in a real app you'd use a geocoding service
    return 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  List<Polyline> _getSelectedRoutePolylines() {
    final polylines = <Polyline>[];
    
    for (final route in _allRoutes) {
      if (_selectedRoutes.contains(route.name) && route.points.isNotEmpty) {
        polylines.add(
          Polyline(
            points: route.points,
            color: route.color,
            strokeWidth: 4.0,
          ),
        );
      }
    }
    
    return polylines;
  }

  List<Marker> _getVisibleMarkers() {
    final markers = <Marker>[];

    // Add current location marker
    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 40.0,
          height: 40.0,
          child: const Icon(Icons.my_location, color: Colors.green, size: 30),
        ),
      );
    }

    // Add terminal markers
    for (final terminal in _allTerminals) {
      markers.add(
        Marker(
          point: terminal.location,
          width: 40.0,
          height: 40.0,
          child: const Icon(Icons.location_city, color: Colors.red),
        ),
      );
    }

    // Add stop markers for selected routes only
    for (final route in _allRoutes) {
      if (_selectedRoutes.contains(route.name)) {
        for (final stop in route.stops) {
          markers.add(
            Marker(
              point: stop.location,
              width: 40.0,
              height: 40.0,
              child: Icon(Icons.directions_bus, color: route.color),
            ),
          );
        }
      }
    }
    
    return markers;
  }
}

// Data model classes
class RouteData {
  final int id;
  final String name;
  final Color color;
  List<LatLng> points;
  final List<StopData> stops;
  
  RouteData({
    required this.id,
    required this.name,
    required this.color,
    required this.points,
    required this.stops,
  });

  Future<void> fetchRoutePoints() async {
    if (stops.length < 2) {
      points = [];
      return;
    }

    List<LatLng> routePoints = [];
    
    // Create simple polyline connecting all stops
    for (final stop in stops) {
      routePoints.add(stop.location);
    }
    
    points = routePoints;
  }

  factory RouteData.fromJson(Map<String, dynamic> json, List<StopData> routeStops) {
    Color routeColor = Colors.blue; // default
    try {
      if (json['color'] != null && json['color'].toString().isNotEmpty) {
        String colorStr = json['color'].toString();
        if (colorStr.startsWith('#')) {
          colorStr = colorStr.substring(1);
        }
        routeColor = Color(int.parse('FF$colorStr', radix: 16));
      }
    } catch (e) {
      print('Error parsing color: $e');
    }

    return RouteData(
      id: int.parse(json['route_id'].toString()),
      name: json['route_name'] ?? '',
      color: routeColor,
      points: [],
      stops: routeStops,
    );
  }
}

class StopData {
  final int? id;
  final String name;
  final LatLng location;
  final String? description;
  
  StopData({
    this.id,
    required this.name,
    required this.location,
    this.description,
  });

  factory StopData.fromJson(Map<String, dynamic> json) {
    return StopData(
      id: json['stop_id'] != null ? int.parse(json['stop_id'].toString()) : null,
      name: json['stop_name'] ?? json['name'] ?? '',
      location: LatLng(
        double.parse(json['latitude'].toString()),
        double.parse(json['longitude'].toString()),
      ),
      description: json['description'],
    );
  }
}

class TerminalData {
  final int id;
  final String name;
  final LatLng location;
  final String? description;
  
  TerminalData({
    required this.id,
    required this.name,
    required this.location,
    this.description,
  });

  factory TerminalData.fromJson(Map<String, dynamic> json) {
    return TerminalData(
      id: int.parse(json['terminal_id'].toString()),
      name: json['terminal_name'] ?? '',
      location: LatLng(
        double.parse(json['latitude'].toString()),
        double.parse(json['longitude'].toString()),
      ),
      description: json['description'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'https://s2121354.helioho.st/MobileAppWebSystem/api/kitkat.php'; // Update with your actual HelioHost domain
  static const String apiKey = 'baco_route_admin_2024';
  static Future<List<RouteData>> getRoutes() async {
    try {
      print('Fetching routes from API...');
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'api_key': apiKey,
          'load': 'routes',
        },
      );

      print('Routes response status: ${response.statusCode}');
      print('Routes response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final routesData = data['routes'] as List;
          print('Found ${routesData.length} routes');
          
          List<RouteData> routes = [];
          
          for (var routeJson in routesData) {
            print('Processing route: ${routeJson['route_name']} (ID: ${routeJson['route_id']})');
            // Get stops for this route
            final routeStops = await getRouteStops(int.parse(routeJson['route_id'].toString()));
            print('Got ${routeStops.length} stops for route ${routeJson['route_name']}');
            
            final route = RouteData.fromJson(routeJson, routeStops);
            routes.add(route);
          }
          
          print('Returning ${routes.length} routes with stops');
          return routes;
        } else {
          print('API error: ${data['message']}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching routes: $e');
    }
    return [];
  }
  static Future<List<StopData>> getRouteStops(int routeId) async {
    try {
      print('Fetching stops for route ID: $routeId');
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'api_key': apiKey,
          'load': 'route_details',
          'route_id': routeId.toString(),
        },
      );

      print('Route details response status: ${response.statusCode}');
      print('Route details response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final route = data['route'];
          print('Route data received: $route');
          
          if (route['stops'] != null) {
            final stopsData = route['stops'] as List;
            print('Found ${stopsData.length} stops for route $routeId');
            final stops = stopsData.map((stopJson) {
              print('Processing stop: $stopJson');
              return StopData.fromJson(stopJson);
            }).toList();
            return stops;
          } else {
            print('No stops found in route data');
          }
        } else {
          print('API error: ${data['message']}');
        }
      } else {
        print('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching route stops: $e');
    }
    return [];
  }

  static Future<List<TerminalData>> getTerminals() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'api_key': apiKey,
          'load': 'terminals',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final terminalsData = data['terminals'] as List;
          return terminalsData.map((terminalJson) => TerminalData.fromJson(terminalJson)).toList();
        }
      }
    } catch (e) {
      print('Error fetching terminals: $e');
    }
    return [];
  }

  static Future<List<StopData>> getStops() async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {
          'api_key': apiKey,
          'load': 'stops',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final stopsData = data['stops'] as List;
          return stopsData.map((stopJson) => StopData.fromJson(stopJson)).toList();
        }
      }
    } catch (e) {
      print('Error fetching stops: $e');
    }
    return [];
  }
}

class RouteService {
  static Future<List<LatLng>> getRoutePoints(LatLng start, LatLng end) async {
    final String baseUrl = 'router.project-osrm.org';
    final uri = Uri.http(baseUrl, '/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}', {
      'overview': 'full',
      'geometries': 'geojson',
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
        
        return coordinates.map((point) {
          return LatLng(point[1], point[0]); // Note: OSRM returns [lng, lat]
        }).toList();
      }
    } catch (e) {
      print('Error fetching route: $e');
    }
    
    // Fallback to direct line if routing fails
    return [start, end];
  }
}
