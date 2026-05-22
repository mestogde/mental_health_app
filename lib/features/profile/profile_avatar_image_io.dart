import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ProfileAvatarImage extends StatelessWidget {
  const ProfileAvatarImage({super.key, required this.path, required this.size});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarPath = path;
    if (avatarPath == null || avatarPath.isEmpty) {
      return _PlaceholderAvatar(size: size);
    }

    final file = File(avatarPath);
    return ClipOval(
      child: Image(
        image: FileImage(file),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _PlaceholderAvatar(size: size),
      ),
    );
  }
}

Future<bool> profileAvatarFileExists(String path) async {
  return File(path).existsSync();
}

Future<String> persistProfileAvatarImage(XFile pickedFile) async {
  final directory = await getApplicationDocumentsDirectory();
  final extension = _extensionFromPath(
    pickedFile.path.isNotEmpty ? pickedFile.path : pickedFile.name,
  );
  final destinationPath = '${directory.path}/profile_avatar_image$extension';
  final destinationFile = File(destinationPath);
  if (destinationFile.existsSync()) {
    await destinationFile.delete();
  }
  final bytes = await pickedFile.readAsBytes();
  await destinationFile.writeAsBytes(bytes, flush: true);
  return destinationPath;
}

String _extensionFromPath(String path) {
  final dotIndex = path.lastIndexOf('.');
  final slashIndex = path.lastIndexOf('/');
  if (dotIndex <= slashIndex || dotIndex == -1) {
    return '';
  }
  return path.substring(dotIndex);
}

class _PlaceholderAvatar extends StatelessWidget {
  const _PlaceholderAvatar({required this.size});

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
