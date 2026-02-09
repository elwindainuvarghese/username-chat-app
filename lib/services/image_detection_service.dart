import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/secrets.dart';

class ImageDetectionService {
  final String _apiUrl = 'https://api.sightengine.com/1.0/check.json';

  // FIX: Use synchronous video check for immediate results as user requested.
  final String _videoApiUrl =
      'https://api.sightengine.com/1.0/video/check-sync.json';

  final String _apiUser = Secrets.apiUser;
  final String _apiSecret = Secrets.apiSecret;

  // Parameter string requested by user
  final String _models =
      'nudity,wad,offensive,text-content,gore,tobacco,money,gambling';

  Future<Map<String, dynamic>> detectImage(XFile imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      request.fields['models'] =
          'genai,nudity,wad,offensive,text-content,face-attributes';
      request.fields['api_user'] = _apiUser;
      request.fields['api_secret'] = _apiSecret;

      request.files.add(
        http.MultipartFile.fromBytes(
          'media',
          await imageFile.readAsBytes(),
          filename: imageFile.name,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error analyzing image: $e');
    }
  }

  // --- Video Section (Fixed Parameters) ---

  Future<Map<String, dynamic>> submitVideoWorkflow(XFile videoFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_videoApiUrl));

      // FIX: Use 'models' instead of 'workflow' as requested to fix 400 error.
      request.fields['models'] = _models;
      request.fields['api_user'] = _apiUser;
      request.fields['api_secret'] = _apiSecret;

      request.files.add(
        http.MultipartFile.fromBytes(
          'media',
          await videoFile.readAsBytes(),
          filename: videoFile.name,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        // Return body in exception for debugging
        throw Exception(
          'Failed to check video: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error processing video: $e');
    }
  }
}
