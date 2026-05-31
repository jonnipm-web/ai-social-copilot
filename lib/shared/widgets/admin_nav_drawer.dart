import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';

class AdminNavDrawer extends StatelessWidget {
  const AdminNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).fullPath ?? '';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Modo Editorial',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _NavItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              route: AppConstants.routeAdmin,
              current: current,
            ),
            _NavItem(
              icon: Icons.style_outlined,
              label: 'Brand Studio',
              route: AppConstants.routeAdminBrands,
              current: current,
            ),
            _NavItem(
              icon: Icons.people_outline,
              label: 'Personas',
              route: AppConstants.routeAdminPersonas,
              current: current,
            ),
            _NavItem(
              icon: Icons.library_books_outlined,
              label: 'Biblioteca',
              route: AppConstants.routeAdminLibrary,
              current: current,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Geradores',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _NavItem(
              icon: Icons.format_quote_outlined,
              label: 'Extrator de Trechos',
              route: AppConstants.routeAdminExtract,
              current: current,
            ),
            _NavItem(
              icon: Icons.auto_awesome_outlined,
              label: 'Reaproveitamento',
              route: AppConstants.routeAdminRepurpose,
              current: current,
            ),
            _NavItem(
              icon: Icons.calendar_month_outlined,
              label: 'Calendário Editorial',
              route: AppConstants.routeAdminCalendar,
              current: current,
            ),
            _NavItem(
              icon: Icons.history_edu_outlined,
              label: 'Histórico Avançado',
              route: AppConstants.routeAdminHistory,
              current: current,
            ),
            const Spacer(),
            const Divider(color: Colors.white12),
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Voltar ao App',
              route: AppConstants.routeHome,
              current: current,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
  });

  bool get _isActive => current == route || current.startsWith('$route/');

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        icon,
        size: 18,
        color: _isActive ? const Color(0xFF6C63FF) : Colors.white54,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: _isActive ? Colors.white : Colors.white70,
          fontWeight: _isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      tileColor: _isActive ? Colors.white.withOpacity(0.05) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
