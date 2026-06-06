import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'menu_tile.dart';

class CommonMenuScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> menuItems;
  final void Function(BuildContext, Map<String, dynamic>) onItemTap;
  final bool showClose;

  const CommonMenuScreen({
    Key? key,
    required this.title,
    required this.menuItems,
    required this.onItemTap,
    this.showClose = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            // gradient: LinearGradient(
            //   colors: [Color(0xFFF8FBFF), Color(0xFFECEFF4)],
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomRight,
            // ),
            ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 40,
              ),
              Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  if (showClose)
                    Positioned(
                      right: 16,
                      top: 10,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),

              // Menu Grid
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (kIsWeb ||
                            Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS)
                        ? 1200 // Wider for desktop/web
                        : 600, // Narrower for mobile/tablet
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(
                      (kIsWeb ||
                              Platform.isWindows ||
                              Platform.isLinux ||
                              Platform.isMacOS)
                          ? 60 // less padding for desktop
                          : 30, // more compact for mobile
                    ),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: menuItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _getCrossAxisCount(width),
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        return FancyMenuCard(
                          item: item,
                          onTap: () => onItemTap(context, item),
                        );
                      },
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Web/Desktop
      return 4;
    } else {
      // Mobile/Tablet (Android/iOS)
      return 2;
    }
  }
}
