import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:reorderables/reorderables.dart';
import '../../models/user.dart';

class AdditionalPhotosWidget extends StatefulWidget {
  final User user;
  final List<File>
      additionalImages; // Imágenes nuevas seleccionadas (sin subir)
  final bool isUploading;
  final VoidCallback onPickAdditionalImages;
  final VoidCallback onUploadAdditionalPhotos;
  final Function(int) onRemoveSelectedImage;
  final Future<void> Function(String) onDeletePhoto;
  // Callback para notificar que se ha reordenado la lista de fotos
  final ValueChanged<List<Photo>> onReorderDone;

  const AdditionalPhotosWidget({
    Key? key,
    required this.user,
    required this.additionalImages,
    required this.isUploading,
    required this.onPickAdditionalImages,
    required this.onUploadAdditionalPhotos,
    required this.onRemoveSelectedImage,
    required this.onDeletePhoto,
    required this.onReorderDone,
  }) : super(key: key);

  @override
  _AdditionalPhotosWidgetState createState() => _AdditionalPhotosWidgetState();
}

class _AdditionalPhotosWidgetState extends State<AdditionalPhotosWidget> {
  // Máximo de fotos adicionales permitidas
  static const int maxAdditionalPhotos = 6;
  late List<Photo> photoList; // Fotos actuales en el servidor

  @override
  void initState() {
    super.initState();
    // Inicializar con las fotos del usuario
    photoList = List.from(widget.user.photos ?? []);
  }

  @override
  void didUpdateWidget(covariant AdditionalPhotosWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si desde afuera cambian las fotos, actualizamos la lista
    if (oldWidget.user.photos != widget.user.photos) {
      setState(() {
        photoList = List.from(widget.user.photos ?? []);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double itemSize = 100.0;
    final int totalSlots = maxAdditionalPhotos;

    // 1️⃣ Usar photoList en lugar de widget.user.photos:
    final photos = photoList;

    // Construir una lista combinada de items (fotos y placeholders)
    final List<Widget> items = List.generate(totalSlots, (index) {
      if (index < photos.length) {
        final photo = photos[index];
        return Container(
          key: ValueKey(photo.id),
          width: itemSize,
          height: itemSize,
          decoration: BoxDecoration(
            color: Colors.black26,
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: photo.url,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[800]),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.redAccent),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => widget.onDeletePhoto(photo.id),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Placeholder: Envuelto en IgnorePointer para desactivar gestos
        return IgnorePointer(
          key: ValueKey("placeholder_$index"),
          child: Container(
            width: itemSize,
            height: itemSize,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.photo_size_select_actual_outlined,
              color: Colors.white30,
            ),
          ),
        );
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Envolver el ReorderableWrap en un PrimaryScrollController
        PrimaryScrollController(
          controller: ScrollController(),
          child: ReorderableWrap(
            needsLongPressDraggable: false,
            spacing: 5,
            runSpacing: 5,
            onReorder: (int oldIndex, int newIndex) {
              // Permitir reordenar solo si se trata de una foto (no placeholder)
              if (oldIndex < photos.length) {
                if (newIndex > photos.length) {
                  newIndex = photos.length;
                }
                setState(() {
                  final movedPhoto = photoList.removeAt(oldIndex);
                  photoList.insert(newIndex, movedPhoto);
                });
                widget.onReorderDone(photoList);
              }
            },
            children: items,
          ),
        ),
        const SizedBox(height: 10),
        // Botón "Agregar Fotos"
        ElevatedButton.icon(
          onPressed: widget.onPickAdditionalImages,
          icon: const Icon(Icons.add_a_photo, color: Colors.black),
          label: const Text(
            'Agregar Fotos',
            style: TextStyle(color: Colors.black),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Fotos nuevas (aún no subidas)
        if (widget.additionalImages.isNotEmpty) ...[
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
            itemCount: widget.additionalImages.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              final file = widget.additionalImages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => widget.onRemoveSelectedImage(index),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.redAccent,
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          // Botón para subir las fotos seleccionadas
          ElevatedButton(
            onPressed:
                widget.isUploading ? null : widget.onUploadAdditionalPhotos,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: widget.isUploading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  )
                : const Text(
                    'Subir Fotos Adicionales',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}
