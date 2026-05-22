import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileAvatarImage extends StatelessWidget {
  const ProfileAvatarImage({super.key, required this.path, required this.size});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEED9D9),
      ),
      child: const Icon(Icons.person_outline, color: Color(0xFF191919)),
    );
  }
}

Future<bool> profileAvatarFileExists(String path) async {
  return false;
}

Future<String> persistProfileAvatarImage(XFile pickedFile) async {
  return pickedFile.path;
}
