import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:classroom_mejorado/features/communities/providers/community_provider.dart';
import 'package:classroom_mejorado/features/tasks/providers/task_provider.dart';
import 'package:classroom_mejorado/features/admin/providers/admin_provider.dart';

/// Widget que configura todos los providers de la aplicación
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider para gestión de comunidades
        ChangeNotifierProvider(
          create: (_) => CommunityProvider(),
        ),
        
        // Provider para gestión de tareas
        ChangeNotifierProvider(
          create: (_) => TaskProvider(),
        ),
        
        // Provider para panel de administración
        ChangeNotifierProvider(
          create: (_) => AdminProvider(),
        ),
      ],
      child: child,
    );
  }
}

/// Extension para facilitar el acceso a los providers
extension BuildContextExtensions on BuildContext {
  // Getters para acceso rápido a los providers
  CommunityProvider get communityProvider => read<CommunityProvider>();
  TaskProvider get taskProvider => read<TaskProvider>();
  AdminProvider get adminProvider => read<AdminProvider>();
  
  // Getters para listening (se actualizan automáticamente)
  CommunityProvider get watchCommunityProvider => watch<CommunityProvider>();
  TaskProvider get watchTaskProvider => watch<TaskProvider>();
  AdminProvider get watchAdminProvider => watch<AdminProvider>();
}