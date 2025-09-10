import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/constants/app_constants.dart';

// Helper function to safely check iOS platform
bool get _isIOS {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS;
  } catch (e) {
    return false;
  }
}

class MainNavigation extends StatefulWidget {
  final Widget child;

  const MainNavigation({
    super.key,
    required this.child,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<NavigationTab> _tabs = [
    NavigationTab(
      route: '/keypad',
      label: 'Keypad',
      icon: Icons.dialpad,
      activeIcon: Icons.dialpad,
    ),
    NavigationTab(
      route: '/recents',
      label: 'Recents',
      icon: Icons.access_time,
      activeIcon: Icons.access_time,
    ),
    NavigationTab(
      route: '/contacts',
      label: 'Contacts',
      icon: Icons.contacts_outlined,
      activeIcon: Icons.contacts,
    ),
    NavigationTab(
      route: '/voicemail',
      label: 'Voicemail',
      icon: MdiIcons.voicemail,
      activeIcon: MdiIcons.voicemail,
    ),
    NavigationTab(
      route: '/settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) {
        setState(() {
          _currentIndex = i;
        });
        break;
      }
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      context.go(_tabs[index].route);
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _buildMaterialBottomNav(), // Use Material design for all platforms
    );
  }

  Widget _buildMaterialBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        selectedLabelStyle: Theme.of(context).bottomNavigationBarTheme.selectedLabelStyle,
        unselectedLabelStyle: Theme.of(context).bottomNavigationBarTheme.unselectedLabelStyle,
        items: _tabs.map((tab) => BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Icon(
              _currentIndex == _tabs.indexOf(tab) ? tab.activeIcon : tab.icon,
              size: 24,
            ),
          ),
          label: tab.label,
          tooltip: tab.label,
        )).toList(),
      ),
    );
  }

}

class NavigationTab {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  NavigationTab({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

// Badge widget for showing unread counts
class NavigationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final bool showBadge;

  const NavigationBadge({
    super.key,
    required this.child,
    required this.count,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge || count == 0) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 1,
              ),
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom app bar for consistent styling across platforms
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return CupertinoNavigationBar(
        middle: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: leading,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        backgroundColor: backgroundColor ?? CupertinoTheme.of(context).barBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            width: 0.5,
          ),
        ),
      );
    }

    return AppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: elevation,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(AppConstants.appBarHeight);
}

// Large title app bar for iOS-style navigation
class LargeTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const LargeTitleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    if (_isIOS) {
      return CupertinoSliverNavigationBar(
        largeTitle: Text(title),
        leading: leading,
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            width: 0.5,
          ),
        ),
      );
    }

    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: actions,
      leading: leading,
      toolbarHeight: 80,
      titleSpacing: 16,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}

