import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:classroom_mejorado/core/providers/theme_provider.dart';
import 'package:classroom_mejorado/core/constants/app_colors.dart';

class ThemeSwitcherWidget extends StatefulWidget {
  const ThemeSwitcherWidget({super.key});

  @override
  State<ThemeSwitcherWidget> createState() => _ThemeSwitcherWidgetState();
}

class _ThemeSwitcherWidgetState extends State<ThemeSwitcherWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpanded ? 200 : 56,
      width: _isExpanded ? 180 : 56,
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          // Expanded options
          if (_isExpanded)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).shadowColor.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 60),
                    _buildThemeOption(
                      context,
                      icon: Icons.light_mode,
                      label: 'Claro',
                      isSelected: themeProvider.themeMode == ThemeMode.light,
                      onTap: () {
                        context.read<ThemeProvider>().setThemeMode(ThemeMode.light);
                        _toggleExpanded();
                      },
                    ),
                    _buildThemeOption(
                      context,
                      icon: Icons.dark_mode,
                      label: 'Oscuro',
                      isSelected: themeProvider.themeMode == ThemeMode.dark,
                      onTap: () {
                        context.read<ThemeProvider>().setThemeMode(ThemeMode.dark);
                        _toggleExpanded();
                      },
                    ),
                    _buildThemeOption(
                      context,
                      icon: Icons.phone_android,
                      label: 'Sistema',
                      isSelected: themeProvider.themeMode == ThemeMode.system,
                      onTap: () {
                        context.read<ThemeProvider>().setThemeMode(ThemeMode.system);
                        _toggleExpanded();
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // Main button
          GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 3.14159,
                    child: Icon(
                      _isExpanded 
                          ? Icons.close 
                          : (isDark ? Icons.dark_mode : Icons.light_mode),
                      color: Colors.white,
                      size: 24,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                  ? AppColors.primary 
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? AppColors.primary 
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}