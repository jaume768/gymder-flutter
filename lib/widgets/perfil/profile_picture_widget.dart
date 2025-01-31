import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user.dart';

class ProfilePictureWidget extends StatelessWidget {
  final User user;
  final File? imageFile;
  final VoidCallback onPickImage;

  const ProfilePictureWidget({
    Key? key,
    required this.user,
    required this.imageFile,
    required this.onPickImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white,
            backgroundImage: imageFile != null
                ? FileImage(imageFile!)
                : (user.profilePicture != null
                    ? CachedNetworkImageProvider(user.profilePicture!.url)
                    : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: onPickImage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                padding: const EdgeInsets.all(8),
                child:
                    const Icon(Icons.camera_alt, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
