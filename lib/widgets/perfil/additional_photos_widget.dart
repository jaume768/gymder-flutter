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

  // NUEVO: callback para notificar que se ha reordenado la lista de fotos
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
    required this.onReorderDone, // Recibimos el callback
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
    final int placeholdersCount = maxAdditionalPhotos - photoList.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tus Fotos Adicionales:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        // ReorderableWrap para fotos existentes
        PrimaryScrollController(
          controller: ScrollController(),
          child: ReorderableWrap(
            // Lo importante: desactivar el "longPress" para arrastrar.
            needsLongPressDraggable: false,
            spacing: 5,
            runSpacing: 5,
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                final item = photoList.removeAt(oldIndex);
                photoList.insert(newIndex, item);
              });
              // Notificamos arriba que hay un nuevo orden
              widget.onReorderDone(photoList);
            },
            children: List.generate(photoList.length, (index) {
              final photo = photoList[index];
              return Container(
                key: ValueKey(photo.id), // Necesario para Reorderable
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: photo.url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => widget.onDeletePhoto(photo.id),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.red,
                          child:
                              Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        // Placeholders (espacios vacíos)
        if (placeholdersCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List.generate(placeholdersCount, (_) {
                return Container(
                  width: itemSize,
                  height: itemSize,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_size_select_actual_outlined,
                    color: Colors.white30,
                  ),
                );
              }),
            ),
          )
        else
          const SizedBox(height: 10),

        // Botón "Agregar Fotos"
        ElevatedButton.icon(
          onPressed: widget.onPickAdditionalImages,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Agregar Fotos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
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
                  Image.file(file, fit: BoxFit.cover),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => widget.onRemoveSelectedImage(index),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
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
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: widget.isUploading
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  )
                : const Text(
                    'Subir Fotos Adicionales',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
          ),
        ],

        const SizedBox(height: 10),
      ],
    );
  }
}
