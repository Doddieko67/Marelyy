// lib/screen/CommunityDetailScreen.dart
import 'package:classroom_mejorado/features/profile/screens/ai_assistant_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importa para interactuar con Firestore
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/screens/community_chat_tab_content.dart';
import 'package:classroom_mejorado/features/communities/screens/community_tasks_tab_content.dart';
import 'package:classroom_mejorado/features/communities/screens/community_calendar_tab_content.dart';
import 'package:classroom_mejorado/features/communities/screens/community_settings_screen.dart';
import 'package:classroom_mejorado/features/admin/screens/community_admin_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId; // Ahora solo recibe el ID

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<DocumentSnapshot> _communityDetailsStream;
  bool _isAdmin = false;
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    // Initialize with default 5 tabs (for regular members)
    _tabController = TabController(
      length: 5,
      vsync: this,
    );
    
    _checkUserPermissions();

    _communityDetailsStream = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .snapshots();
  }

  Future<void> _checkUserPermissions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoadingPermissions = false;
        });
        return;
      }

      final memberDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .doc(user.uid)
          .get();

      if (memberDoc.exists) {
        final role = memberDoc.data()?['role'] ?? 'member';
        final newIsAdmin = role == 'owner' || role == 'admin';
        
        setState(() {
          _isAdmin = newIsAdmin;
          _isLoadingPermissions = false;
        });

        // Only recreate TabController if admin status changed
        if (newIsAdmin) {
          _tabController.dispose();
          _tabController = TabController(
            length: 6, // 6 tabs for admins
            vsync: this,
          );
        }
      } else {
        setState(() {
          _isLoadingPermissions = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPermissions = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Widget> _buildTabs() {
    List<Widget> tabs = [
      _buildTab("Chat"),
      _buildTab("Tareas"),
      _buildTab("Calendario"),
      _buildTab("IA"),
    ];
    
    if (_isAdmin) {
      tabs.add(_buildTab("Admin"));
    }
    
    tabs.add(_buildTab("Ajustes"));
    return tabs;
  }

  List<Widget> _buildTabViewsWithCommunityName(String communityName) {
    List<Widget> tabViews = [
      CommunityChatTabContent(communityId: widget.communityId),
      CommunityTasksTabContent(communityId: widget.communityId),
      CommunityCalendarTabContent(communityId: widget.communityId),
      AIAssistantScreen(communityId: widget.communityId),
    ];
    
    if (_isAdmin) {
      tabViews.add(CommunityAdminScreen(
        communityId: widget.communityId,
        communityName: communityName,
      ));
    }
    
    tabViews.add(CommunitySettingsScreen(
      communityId: widget.communityId,
      communityName: communityName,
    ));
    
    return tabViews;
  }

  // ************ INICIO DEL CAMBIO IMPORTANTE: Simplificación de _buildTab ************
  // Widget auxiliar para las pestañas (TabBar items)
  Widget _buildTab(String title) {
    // Ya no necesitamos 'index' ni 'context' para el estilo de la barra activa
    return Tab(
      // El widget Tab es lo que espera TabBar.
      // El estilo de la pestaña activa/inactiva y la barra indicadora
      // se controlan directamente en las propiedades del TabBar.
      child: Text(
        title,
        style: TextStyle(
          fontFamily: fontFamilyPrimary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.015 * 14,
          // No definimos el color aquí, TabBar.labelColor/unselectedLabelColor lo harán
        ),
      ),
    );
  }
  // ************ FIN DEL CAMBIO IMPORTANTE ************

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isLoadingPermissions
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            : StreamBuilder<DocumentSnapshot>(
                stream: _communityDetailsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snapshot.error}', // Puede dejarse en inglés o traducir 'Error: '
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    );
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return Center(
                      child: Text(
                        '¡Comunidad no encontrada!', // Traducido
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    );
                  }

                  final communityData = snapshot.data!.data() as Map<String, dynamic>;
                  final String communityName =
                      communityData['name'] ?? 'Cargando...'; // Traducido

                  return Column(
                    children: <Widget>[
                // Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 16.0,
                    bottom: 8.0,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: Icon(
                            Icons.arrow_back,
                            color: theme.colorScheme.onBackground,
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          communityName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.015 * 18,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ),
                      // Placeholder para mantener el título centrado si se añade un icono a la derecha
                      // const SizedBox(width: 48),
                    ],
                  ),
                ),

                // Tabs de la comunidad
                Padding(
                  padding: const EdgeInsets.only(bottom: 3.0),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor:
                          theme.colorScheme.primary, // La única barra visible
                      indicatorWeight: 3,
                      labelColor: theme
                          .colorScheme
                          .onBackground, // Color del texto de la pestaña activa
                      unselectedLabelColor: theme
                          .colorScheme
                          .secondary, // Color del texto de la pestaña inactiva
                      // Los estilos del texto de las pestañas se definen aquí, en el TabBar
                      labelStyle: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.015 * 14,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontFamily: fontFamilyPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.015 * 14,
                      ),
                      // ************ Llamadas a _buildTab ahora simplificadas y traducidas ************
                      tabs: _buildTabs(),
                      // ************ FIN DEL CAMBIO ************
                    ),
                  ),
                ),

                // Contenido de las pestañas
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _buildTabViewsWithCommunityName(communityName),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
