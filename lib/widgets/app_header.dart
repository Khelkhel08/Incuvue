import 'package:flutter/material.dart';

import 'app_logo.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final bool showSettings;
  final bool showLogout;
  final bool showLogoLeading;
  final bool showLogoTrailing;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  const AppHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.showSettings = false,
    this.showLogout = false,
    this.showLogoLeading = false,
    this.showLogoTrailing = false,
    this.onSettings,
    this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      leading: showBack
          ? IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
            )
          : showLogoLeading
              ? const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Center(child: AppLogo(size: 28)),
                )
              : null,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      actions: [
        if (showSettings)
          IconButton(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
          )
        else if (showLogoTrailing && !showLogout)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Center(child: AppLogo(size: 28)),
          )
        else if (!showLogout)
          const SizedBox(width: 48),
        if (showLogout)
          IconButton(
            tooltip: 'Log out',
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.black87),
          ),
      ],
    );
  }
}
