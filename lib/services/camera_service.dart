import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config_service.dart';

class CameraService {
  static Future<String> get _baseUrl async => '${await ConfigService.getBaseUrl()}/api/upload';
  
  final ImagePicker _picker = ImagePicker();

  Future<String?> _getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  Future<String?> uploadPhoto(File imageFile, String jobId, String meterType) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        print('❌ Photo file does not exist: ${imageFile.path}');
        return null;
      }
      
      final baseUrl = await _baseUrl;
      final uploadUrl = '$baseUrl/meter-photo';
      print('📸 Uploading photo to: $uploadUrl');
      print('📸 Photo details: jobId=$jobId, meterType=$meterType, path=${imageFile.path}');
      
      // Get authentication token
      String? token = await _getToken();
      if (token == null) {
        print('❌ No authentication token found');
        return null;
      }
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(uploadUrl),
      );
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      
      request.fields['jobId'] = jobId;
      request.fields['meterType'] = meterType;
      
      // Get file extension to determine content type
      final extension = imageFile.path.split('.').last.toLowerCase();
      MediaType contentType = MediaType('image', 'jpeg'); // default
      if (extension == 'png') {
        contentType = MediaType('image', 'png');
      } else if (extension == 'gif') {
        contentType = MediaType('image', 'gif');
      } else if (extension == 'webp') {
        contentType = MediaType('image', 'webp');
      }
      
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
        contentType: contentType,
      ));
      
      print('📤 Sending photo upload request with token...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print('📥 Upload response: status=${response.statusCode}, body=${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final photoUrl = responseData['photoUrl'];
        if (photoUrl != null && photoUrl.toString().isNotEmpty) {
          print('✅ Photo uploaded successfully: $photoUrl');
          return photoUrl.toString();
        } else {
          print('❌ Photo upload succeeded but no photoUrl in response: $responseData');
          return null;
        }
      } else {
        final errorData = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        print('❌ Upload failed: status=${response.statusCode}, error=${errorData['message'] ?? response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error uploading photo: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  Future<List<String>> uploadMultiplePhotos(List<File> imageFiles, String jobId) async {
    List<String> uploadedUrls = [];
    
    for (File imageFile in imageFiles) {
      String? url = await uploadPhoto(imageFile, jobId, 'general');
      if (url != null) {
        uploadedUrls.add(url);
      }
    }
    
    return uploadedUrls;
  }

  Future<File> saveImageToLocal(File imageFile, String fileName) async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      String localPath = '${appDir.path}/$fileName';
      File localFile = await imageFile.copy(localPath);
      return localFile;
    } catch (e) {
      print('Error saving image locally: $e');
      return imageFile;
    }
  }
}
