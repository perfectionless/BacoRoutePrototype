import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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

  final LatLng _bacolodCityCenter = LatLng(10.6713, 122.9511);

  final LatLngBounds _bacolodCityBounds = LatLngBounds(
    LatLng(10.6200, 122.9000),
    LatLng(10.7200, 123.0000),
  );

  final List<RouteData> _allRoutes = [
    RouteData(
      id: 1,
      name: 'Banago-Libertad Loop',
      color: Colors.red,
      points: [
        LatLng(10.6713, 122.9511), 
        LatLng(10.6800, 122.9600), 
        LatLng(10.6850, 122.9650), 
      ],
      stops: [
        StopData(name: 'Banago Terminal', location: LatLng(10.6713, 122.9511)),
        StopData(name: 'Libertad Stop', location: LatLng(10.6850, 122.9650)),
      ],
    ),
    RouteData(
      id: 2,
      name: 'Bata-Libertad Loop',
      color: Colors.green,
      points: [
        LatLng(14.6100, 120.9800),
        LatLng(14.6050, 120.9850),
        LatLng(14.6050, 120.9950),
      ],
      stops: [
        StopData(name: 'Bata Terminal', location: LatLng(14.6100, 120.9800)),
        StopData(name: 'Libertad Stop', location: LatLng(14.6050, 120.9950)),
      ],
    ),
    RouteData(
      id: 3,
      name: 'Northbound Terminal - Libertad Loop',
      color: Colors.purple,
      points: [
        LatLng(14.6150, 120.9750),
        LatLng(14.6100, 120.9800),
        LatLng(14.6050, 120.9950),
      ],
      stops: [
        StopData(name: 'Northbound Terminal', location: LatLng(14.6150, 120.9750)),
        StopData(name: 'Libertad Stop', location: LatLng(14.6050, 120.9950)),
      ],
    ),
  ];

  List<StopData> get _allStops {
    final allStops = <StopData>[];
    for (final route in _allRoutes) {
      for (final stop in route.stops) {
        if (!allStops.any((s) => s.name == stop.name)) {
          allStops.add(stop);
        }
      }
    }
    return allStops;
  }

  @override
  void initState() {
    super.initState();
    _initializeRoutes();
  }

  Future<void> _initializeRoutes() async {
    for (final route in _allRoutes) {
      await route.fetchRoutePoints();
    }
    setState(() {}); // Refresh display with new route points
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BACO-ROUTE', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
        
            },
          ),
        ],
      ),
      body: Stack(
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
            maxChildSize: 0.6,
            snapSizes: const [0.3, 0.6],
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
                child: const Text('Select All'),
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
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search routes',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {

            },
          ),
        ),
        
        // Routes list
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),  // Disable scrolling
          shrinkWrap: true,  // Important!
          padding: const EdgeInsets.only(top: 16),
          itemCount: _allRoutes.length,
          itemBuilder: (context, index) {
            final route = _allRoutes[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: route.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: route.color),
              ),
              child: CheckboxListTile(
                title: Text(
                  "${route.id} ${route.name}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _selectedRoutes.contains(route.name),
                activeColor: route.color,
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
            );
          },
        ),
      ],
    );
  }

  // Terminals tab content
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
              // Toggle visibility
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
        
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search terminals',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              // Implement search functionality
            },
          ),
        ),
        
        // Terminals list
        ListView.builder(
          controller: scrollController,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.only(top: 16),
          itemCount: _allStops.length,
          itemBuilder: (context, index) {
            final stop = _allStops[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(stop.name),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  // Center map on this terminal
                  _mapController.move(stop.location, 15.0);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // Route finder tab content
  Widget _buildFinderView(ScrollController scrollController) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Plan Your Trip', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 16),
          
          // Origin field
          TextField(
            decoration: InputDecoration(
              labelText: 'Starting Point',
              prefixIcon: const Icon(Icons.my_location),
              suffixIcon: IconButton(
                icon: const Icon(Icons.gps_fixed),
                onPressed: () {
                  // Use current location as starting point
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Destination field
          TextField(
            decoration: InputDecoration(
              labelText: 'Destination',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Find routes button
          ElevatedButton.icon(
            onPressed: () {
              // Implement route finding functionality
              _showRouteSuggestions(context);
            },
            icon: const Icon(Icons.directions),
            label: const Text('Find Routes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          
          const SizedBox(height: 16),
          const Text(
            'Tip: Select your starting point and destination to find the best jeepney routes.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Helper method to display route suggestions
  void _showRouteSuggestions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suggested Routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    // This would be populated with actual route suggestions
                    _buildRouteSuggestionItem(
                      'Direct Route',
                      'Take Banago-Libertad Loop (45 mins)',
                      Colors.red,
                    ),
                    _buildRouteSuggestionItem(
                      'Alternative Route',
                      'Take Bata-Libertad Loop → Transfer at Central Market → Take Northbound-Libertad Loop (55 mins)',
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to create route suggestion item
  Widget _buildRouteSuggestionItem(String title, String description, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  // Show this route on the map
                  Navigator.pop(context);
                },
                child: const Text('Show on Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get polylines for selected routes
  List<Polyline> _getSelectedRoutePolylines() {
    final polylines = <Polyline>[];
    
    for (final route in _allRoutes) {
      if (_selectedRoutes.contains(route.name)) {
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

  // Helper method to get markers for visible stops
  List<Marker> _getVisibleMarkers() {
    final markers = <Marker>[];
    
    // If we're in terminals view, show all stops
    // If we're in routes view, only show stops for selected routes
    if (_currentIndex == 1) {
      // Show all terminals
      for (final stop in _allStops) {
        markers.add(
          Marker(
            point: stop.location,
            width: 40.0,
            height: 40.0,
            child: const Icon(Icons.location_on, color: Colors.red),
          ),
        );
      }
    } else {
      // Show stops for selected routes
      for (final route in _allRoutes) {
        if (_selectedRoutes.contains(route.name)) {
          for (final stop in route.stops) {
            markers.add(
              Marker(
                point: stop.location,
                width: 40.0,
                height: 40.0,
                child: Icon(Icons.location_on, color: route.color),
              ),
            );
          }
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
    List<LatLng> routePoints = [];
    
    // Get route segments between consecutive stops
    for (int i = 0; i < stops.length - 1; i++) {
      final pointsList = await RouteService.getRoutePoints(
        stops[i].location,
        stops[i + 1].location
      );
      routePoints.addAll(pointsList);
    }
    
    points = routePoints;
  }
}

class StopData {
  final String name;
  final LatLng location;
  
  StopData({
    required this.name,
    required this.location,
  });
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