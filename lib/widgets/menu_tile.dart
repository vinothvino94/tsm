import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

class FancyMenuCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const FancyMenuCard({
    Key? key,
    required this.item,
    required this.onTap,
  }) : super(key: key);

  @override
  State<FancyMenuCard> createState() => _FancyMenuCardState();
}

/*class _FancyMenuCardState extends State<FancyMenuCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = (widget.item['iconColor'] ??
        widget.item['color'] ??
        Colors.blue) as Color;

    // default background
    final Color baseBg = AppColors.primaryModerate.withOpacity(0.2);

    // background color changes on hover
    final Color cardBg =
        _hovering ? AppColors.primaryModerate.withOpacity(0.2) : baseBg;

    // decide text color
    final Brightness brightness = ThemeData.estimateBrightnessForColor(cardBg);
    final Color textColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _hovering
                    ? AppColors.primaryModerate.withOpacity(0.4)
                    : AppColors.primaryModerate.withOpacity(0.25),
                blurRadius: _hovering ? 12 : 8,
                offset: Offset(0, _hovering ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: iconColor.withOpacity(0.15),
                child: Icon(
                  widget.item['icon'] as IconData,
                  color: iconColor,
                  size: 30,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                widget.item['title'] as String,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/

class _FancyMenuCardState extends State<FancyMenuCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final iconSize = isMobile ? 32.0 : 45.0;
    final padding = isMobile ? 10.0 : 30.0;
    final fontSize = isMobile ? 14.0 : 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12,
          vertical: isMobile ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: _hovering
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  decoration: BoxDecoration(
                    color: _hovering
                        ? Colors.white.withOpacity(0.9)
                        : AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _hovering
                          ? Colors.transparent
                          : AppColors.primaryLight,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    widget.item['icon'] as IconData,
                    color:
                        _hovering ? AppColors.primaryDark : AppColors.primary,
                    size: iconSize,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.item['title'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _hovering ? Colors.white : AppColors.primaryDark,
                    fontWeight: _hovering ? FontWeight.bold : FontWeight.w600,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
