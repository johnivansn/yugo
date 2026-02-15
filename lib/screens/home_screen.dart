import 'package:flutter/material.dart';
import 'package:yugo/screens/app_list_screen.dart';
import 'package:yugo/screens/discipline_mode_screen.dart';
import 'package:yugo/screens/macro_editor_screen.dart';
import 'package:yugo/screens/macro_list_screen.dart';
import 'package:yugo/screens/permissions_screen.dart';
import 'package:yugo/screens/habit_macro_list_screen.dart';
import 'package:yugo/screens/discipline_macro_list_screen.dart';
import 'package:yugo/screens/habit_wizard_screen.dart';
import 'package:yugo/screens/macro_library_screen.dart';
import 'package:yugo/theme/app_palette.dart';
import 'package:yugo/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yugo'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.lg),
          _HeaderCard(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'ACCESOS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Macros',
            subtitle: 'Reglas y automatizaciones',
            color: AppPalette.accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MacroListScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.self_improvement,
            title: 'Macros de Hábito',
            subtitle: 'Persistentes con estado',
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HabitMacroListScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.lock_clock_rounded,
            title: 'Macros de Disciplina',
            subtitle: 'Contextuales sin hábito',
            color: AppColors.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DisciplineMacroListScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.account_tree_rounded,
            title: 'Modo Avanzado',
            subtitle: 'Editor visual de macros',
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MacroEditorScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.route_rounded,
            title: 'Modo Simple',
            subtitle: 'Wizard para hábitos rápidos',
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HabitWizardScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.security_rounded,
            title: 'Permisos',
            subtitle: 'Uso, accesibilidad y overlay',
            color: AppColors.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PermissionsScreen()),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.apps_rounded,
            title: 'Límites',
            subtitle: 'Control diario por app',
            color: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppListScreen(initialBlocks: []),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.lock_clock_rounded,
            title: 'Modo Disciplina',
            subtitle: 'Bloqueos contextuales',
            color: AppPalette.accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DisciplineModeScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.library_books_rounded,
            title: 'Biblioteca',
            subtitle: 'Macros reutilizables',
            color: AppPalette.accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MacroLibraryScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.asset(
                  'assets/icon_dark.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.shield_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automatiza tu disciplina',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Controla macros y disciplina desde un solo lugar.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


