import 'dart:convert';
import 'dart:io';

void main() async {
  await testAPI();
}

Future<void> testAPI() async {
  print('Testing API integration...');
  
  // Test routes endpoint
  try {
    var request = await HttpClient().postUrl(
      Uri.parse('http://localhost/MobileAppWebSystem/api/kitkat.php')
    );
    request.headers.set('content-type', 'application/x-www-form-urlencoded');
    request.write('api_key=baco_route_admin_2024&load=routes');
    
    var response = await request.close();
    var responseBody = await response.transform(utf8.decoder).join();
    
    print('Routes API Response:');
    print('Status: ${response.statusCode}');
    print('Body: $responseBody');
    
    if (response.statusCode == 200) {
      var data = jsonDecode(responseBody);
      if (data['status'] == 'success') {
        var routes = data['routes'] as List;
        print('\nFound ${routes.length} routes:');
        
        for (var route in routes) {
          print('- ${route['route_name']} (ID: ${route['route_id']})');
          
          // Test route details for each route
          await testRouteDetails(int.parse(route['route_id'].toString()));
        }
      }
    }
  } catch (e) {
    print('Error testing routes API: $e');
  }
}

Future<void> testRouteDetails(int routeId) async {
  try {
    var request = await HttpClient().postUrl(
      Uri.parse('http://localhost/MobileAppWebSystem/api/kitkat.php')
    );
    request.headers.set('content-type', 'application/x-www-form-urlencoded');
    request.write('api_key=baco_route_admin_2024&load=route_details&route_id=$routeId');
    
    var response = await request.close();
    var responseBody = await response.transform(utf8.decoder).join();
    
    print('\nRoute $routeId Details:');
    print('Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      var data = jsonDecode(responseBody);
      if (data['status'] == 'success') {
        var route = data['route'];
        if (route['stops'] != null) {
          var stops = route['stops'] as List;
          print('  Stops: ${stops.length}');
          for (var stop in stops) {
            print('    - ${stop['stop_name']} (${stop['latitude']}, ${stop['longitude']})');
          }
        } else {
          print('  No stops found in response');
        }
      } else {
        print('  API Error: ${data['message']}');
      }
    } else {
      print('  HTTP Error: ${response.statusCode}');
    }
  } catch (e) {
    print('Error testing route details: $e');
  }
}
