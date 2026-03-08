import 'dart:io';
import 'package:cloudinary/cloudinary.dart';

class CloudinaryService {
  static final cloudinary = Cloudinary.signedConfig(
    apiKey: '871275349882889',
    apiSecret: 'JpKJ0dYffndprjwQIpBa8R2MHQo=',
    cloudName: 'dcja9phn5',
  );

  static Future<String?> uploadIdProof(File imageFile) async {
    try {
      final response = await cloudinary.upload(
        file: imageFile.path,
        resourceType: CloudinaryResourceType.image,
        folder: 'id-proof',
        fileName: 'id_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (response.isSuccessful) {
        return response.secureUrl;
      } else {
        print("Cloudinary Upload Failed: ${response.error}");
        return null;
      }
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }
}
