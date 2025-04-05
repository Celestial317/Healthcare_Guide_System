import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert'; // For JSON parsing
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DiseaseInfoScreen(),
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: Colors.transparent,
      ),
    );
  }
}

class DiseaseInfoScreen extends StatefulWidget {
  const DiseaseInfoScreen({super.key});

  @override
  _DiseaseInfoScreenState createState() => _DiseaseInfoScreenState();
}

class _DiseaseInfoScreenState extends State<DiseaseInfoScreen> {
  final TextEditingController _diseaseController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  Map<String, dynamic>? diseaseInfo;
  bool isLoading = false;

  Future<void> fetchDiseaseInfo(String disease, String city) async {
    if (disease.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both a disease name and a city')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      diseaseInfo = null; // Reset diseaseInfo to null while fetching
    });
    print('Starting fetchDiseaseInfo for disease: $disease, city: $city');

    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);

      const String baseUrl = 'https://healthadvisor2-9.onrender.com';
      print('Sending request to: $baseUrl/api/disease/info');
      final response = await dio.post(
        '$baseUrl/api/disease/info',
        data: {'disease': disease, 'city': city},
        options: Options(
          validateStatus: (status) => (status ?? 0) < 500,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      print('Request completed with status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response data: ${response.data}');
      print('Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> parsedData;

        if (response.data is String) {
          try {
            final cleanedData = response.data.replaceAll('\n', '').trim();
            parsedData = jsonDecode(cleanedData) as Map<String, dynamic>;
            print('Parsed data (from string): $parsedData');
          } catch (e) {
            print('JSON parsing error: $e');
            throw Exception('Failed to parse JSON string: ${response.data}, Error: $e');
          }
        } else if (response.data is Map<String, dynamic>) {
          parsedData = response.data;
          print('Parsed data (already a map): $parsedData');
        } else {
          throw Exception('Invalid response format: Expected a JSON string or Map, but got ${response.data.runtimeType}');
        }

        if (parsedData.containsKey('error')) {
          throw Exception('Server error: ${parsedData['error']}');
        }

        // Parse nested JSON strings in hospitals, budget, and insurance_companies
        if (parsedData['hospitals'] != null && parsedData['hospitals'] is List) {
          parsedData['hospitals'] = (parsedData['hospitals'] as List).map((hospital) {
            if (hospital is String) {
              try {
                return jsonDecode(hospital) as Map<String, dynamic>;
              } catch (e) {
                print('Error parsing hospital JSON: $hospital, Error: $e');
                return {'name': 'Unknown Hospital', 'error': 'Failed to parse hospital data'};
              }
            }
            return hospital;
          }).toList();
        }

        if (parsedData['budget'] != null && parsedData['budget'] is String) {
          try {
            parsedData['budget'] = jsonDecode(parsedData['budget']) as Map<String, dynamic>;
          } catch (e) {
            print('Error parsing budget JSON: ${parsedData['budget']}, Error: $e');
            parsedData['budget'] = {'error': 'Failed to parse budget data'};
          }
        }

        // Handle insurance_companies as a List<String>
        if (parsedData['insurance_companies'] != null && parsedData['insurance_companies'] is List) {
          parsedData['insurance_companies'] = (parsedData['insurance_companies'] as List).map((insurance) {
            if (insurance is String) {
              // If it's a plain string, wrap it in a Map with a "name" field
              return {'name': insurance};
            } else if (insurance is Map<String, dynamic>) {
              return insurance;
            } else {
              print('Unexpected insurance company format: $insurance');
              return {'name': 'Unknown Insurance', 'error': 'Unexpected format'};
            }
          }).toList();
        }

        print('Parsed data keys: ${parsedData.keys}');
        print('Parsed hospitals: ${parsedData['hospitals']}');
        print('Parsed budget: ${parsedData['budget']}');
        print('Parsed insurance_companies: ${parsedData['insurance_companies']}');

        setState(() {
          diseaseInfo = parsedData;
          print('diseaseInfo set to: $diseaseInfo');
          print('diseaseInfo type: ${diseaseInfo.runtimeType}');
        });
      } else {
        throw Exception('Invalid response: Status code ${response.statusCode}, Data: ${response.data}');
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to fetch info';
      if (e.response != null) {
        errorMessage += ': ${e.response?.statusCode} - ${e.response?.data}';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timed out. Please check your network or server status.';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Server took too long to respond. Please try again later.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Cannot connect to the server. Please ensure the server is running and the device is connected to the same network.';
      } else {
        errorMessage += ': ${e.message ?? 'Unknown error'}';
      }
      print('DioException: $errorMessage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print('Unexpected error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: ${e.toString()}')),
      );
    } finally {
      print('Exiting fetchDiseaseInfo, setting isLoading to false');
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _diseaseController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E2F), Color(0xFF2E2E4F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Disease Info Finder',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _diseaseController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter Disease Name',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      suffixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _cityController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter City Name',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      suffixIcon: const Icon(
                        Icons.search,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: GestureDetector(
                  onTap: () => fetchDiseaseInfo(_diseaseController.text.trim(), _cityController.text.trim()),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A00F4), Color(0xFF00DDEB)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Get Information',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (isLoading)
                FadeIn(
                  duration: const Duration(milliseconds: 500),
                  child: const SpinKitWave(
                    color: Colors.white,
                    size: 50.0,
                  ),
                ),
              if (diseaseInfo != null && !isLoading)
                Expanded(
                  child: FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    child: DiseaseInfoDisplay(data: diseaseInfo!),
                  ),
                )
              else if (!isLoading)
                FadeIn(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'No data available. Enter a disease name and city to search.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiseaseInfoDisplay extends StatelessWidget {
  final Map<String, dynamic> data;

  const DiseaseInfoDisplay({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['hospitals'] != null && data['hospitals'] is List && (data['hospitals'] as List).isNotEmpty) ...[
            Text(
              'Hospitals',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ...(data['hospitals'] as List).asMap().entries.map((entry) {
              final index = entry.key;
              final hospital = entry.value as Map<String, dynamic>?;
              return FadeInUp(
                duration: Duration(milliseconds: 500 + (index * 100)),
                child: Card(
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      hospital?['name']?.toString() ?? 'Unknown Hospital',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      'Specializations: ${hospital?['specializations']?.toString() ?? hospital?['specialization']?.toString() ?? hospital?['speciality']?.toString() ?? 'N/A'}\nAddress: ${hospital?['address']?.toString() ?? 'N/A'}\nPhone: ${hospital?['phone']?.toString() ?? 'N/A'}\nWebsite: ${hospital?['website']?.toString() ?? 'N/A'}\nServices: ${hospital?['heart_attack_services']?.toString() ?? 'N/A'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
          ],
          if (data['budget'] != null && data['budget'] is Map) ...[
            Text(
              'Budget',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consultation: ${(data['budget'] as Map)['consultation']?.toString() ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Tests: ${(data['budget'] as Map)['tests']?.toString() ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Medications: ${(data['budget'] as Map)['medications']?.toString() ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Hospitalization: ${(data['budget'] as Map)['hospitalization']?.toString() ?? 'N/A'}',
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (data['insurance_companies'] != null && data['insurance_companies'] is List && (data['insurance_companies'] as List).isNotEmpty) ...[
            Text(
              'Insurance Companies',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            ...(data['insurance_companies'] as List).asMap().entries.map((entry) {
              final index = entry.key;
              final insurance = entry.value as Map<String, dynamic>;
              return FadeInUp(
                duration: Duration(milliseconds: 500 + (index * 100)),
                child: Card(
                  color: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(
                      insurance['name']?.toString() ?? 'Unknown Insurance',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      insurance['notes']?.toString() ?? 'No additional notes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
          ],
          if (data['cost'] != null)
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Estimated Cost: ${data['cost'].toString()}',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (data['recovery_time'] != null)
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Recovery Time: ${data['recovery_time'].toString()}',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}