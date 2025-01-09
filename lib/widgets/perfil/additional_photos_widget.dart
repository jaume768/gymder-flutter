import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user.dart';

class AdditionalPhotosWidget extends StatelessWidget {
  final User user;
  final List<File> additionalImages;
  final bool isUploading;
  final VoidCallback onPickAdditionalImages;
  final VoidCallback onUploadAdditionalPhotos;
  final Function(int) onRemoveSelectedImage;
  final Future<void> Function(String) onDeletePhoto;

  const AdditionalPhotosWidget({
    Key? key,
    required this.user,
    required this.additionalImages,
    required this.isUploading,
    required this.onPickAdditionalImages,
    required this.onUploadAdditionalPhotos,
    required this.onRemoveSelectedImage,
    required this.onDeletePhoto,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photos = user.photos ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tus Fotos:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        photos.isEmpty
            ? const Text(
                'No tienes fotos.',
                style: TextStyle(color: Colors.white70),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: photo.url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => onDeletePhoto(photo.id),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: onPickAdditionalImages,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Agregar Fotos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            if (additionalImages.isNotEmpty) ...[
              const Text(
                'Fotos Seleccionadas:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: additionalImages.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                ),
                itemBuilder: (context, index) {
                  final file = additionalImages[index];
                  return Stack(
                    children: [
                      Image.file(
                        file,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => onRemoveSelectedImage(index),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: isUploading ? null : onUploadAdditionalPhotos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: isUploading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      )
                    : const Text(
                        'Subir Fotos Adicionales',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
