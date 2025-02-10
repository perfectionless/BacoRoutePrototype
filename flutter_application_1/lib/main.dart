import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jeepney Route Finder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  bool _showStops = true;
  List<String> _selectedRoutes = [];

  final List<String> _allRoutes = [
    'Route 12: Ayala to SM City',
    'Route 15: Market to Campus',
    'Route 20: Park to Terminal',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jeepney Route Finder'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Add settings functionality here
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(14.5995, 120.9842), // Default location (Manila)
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              if (_showStops)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(14.5995, 120.9842),
                      width: 40.0,
                      height: 40.0,
                      child: Icon(Icons.location_on, color: Colors.red),
                    ),
                    Marker(
                      point: LatLng(14.6000, 120.9900),
                      width: 40.0,
                      height: 40.0,
                      child: Icon(Icons.location_on, color: Colors.blue),
                    ),
                  ],
                ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(14.5995, 120.9842),
                      LatLng(14.6000, 120.9900),
                    ],
                    color: Colors.blue,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
            ],
          ),

          // Expandable Menu
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.3,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Route Selection
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Select Routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ..._allRoutes.map((route) {
                      return CheckboxListTile(
                        title: Text(route),
                        value: _selectedRoutes.contains(route),
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              _selectedRoutes.add(route);
                            } else {
                              _selectedRoutes.remove(route);
                            }
                          });
                        },
                      );
                    }).toList(),

                    // Stops/Terminals Toggle
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Text('Show Stops/Terminals'),
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

                    // Route Planner
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Plan Your Trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Starting Point'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: TextField(
                        decoration: InputDecoration(labelText: 'Destination'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // Add route planning functionality here
                        },
                        child: Text('Find Routes'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
