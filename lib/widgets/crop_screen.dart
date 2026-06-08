import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

class CropScreen extends StatefulWidget {
  final List<int> imageBytes;
  final void Function(Uint8List croppedBytes) onCropped;

  const CropScreen({
    Key? key,
    required this.imageBytes,
    required this.onCropped,
  }) : super(key: key);

  @override
  _CropScreenState createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final cropController = CropController();
  double? _aspectRatio; // null = freestyle

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crop Image"),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_90_degrees_ccw),
            onPressed: () => {},
          ),
          PopupMenuButton<double?>(
            icon: const Icon(Icons.aspect_ratio),
            onSelected: (value) => setState(() => _aspectRatio = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('Free')),
              const PopupMenuItem(value: 1.0, child: Text('1:1')),
              const PopupMenuItem(value: 16 / 9, child: Text('16:9')),
              const PopupMenuItem(value: 4 / 3, child: Text('4:3')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: Uint8List.fromList(widget.imageBytes),
              controller: cropController,
              onCropped: (image) {
                widget.onCropped(image as Uint8List);
                Navigator.pop(context, image);
              },
              aspectRatio: _aspectRatio,
              fixArea: false,
              baseColor: Colors.black,
              maskColor: Colors.black.withOpacity(0.5),
              cornerDotBuilder: (size, index) => const DotControl(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => cropController.crop(),
                  child: const Text("Crop"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DotControl extends StatelessWidget {
  const DotControl({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        shape: BoxShape.circle,
      ),
    );
  }
}
