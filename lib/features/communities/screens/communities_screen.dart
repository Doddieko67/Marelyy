// lib/screen/CommunitiesScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/features/communities/screens/create_community_screen.dart';

class CommunitiesScreen extends StatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  State<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends State<CommunitiesScreen>
    with WidgetsBindingObserver, RouteAware {
  late Stream<QuerySnapshot> _communitiesStream;
  late Stream<QuerySnapshot> _lastVisitsStream;
  Map<String, DateTime> _lastVisitsCache = {};
  bool _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStreams();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsRefresh) {
      setState(() {
        _initializeStreams();
        _needsRefresh = false;
      });
    }
  }

  void _initializeStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _communitiesStream = FirebaseFirestore.instance
          .collection('communities')
          .where('members', arrayContains: user.uid)
          .snapshots();

      _lastVisitsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('lastVisits')
          .snapshots();
    }
  }

  void _refreshCommunities() {
    setState(() {
      _initializeStreams();
      _lastVisitsCache.clear();
    });
  }

  // Función optimizada que usa cache local para actualizaciones instantáneas
  List<Map<String, dynamic>> _sortCommunitiesWithCache(
    List<QueryDocumentSnapshot> communities,
    Map<String, DateTime> lastVisitsMap,
  ) {
    List<Map<String, dynamic>> communitiesWithVisit = [];

    for (var community in communities) {
      final communityId = community.id;
      final communityData = community.data() as Map<String, dynamic>;

      // Usar cache local primero, luego datos de Firestore
      final lastVisit =
          _lastVisitsCache[communityId] ?? lastVisitsMap[communityId];

      communitiesWithVisit.add({
        'id': communityId,
        'data': communityData,
        'lastVisit': lastVisit,
      });
    }

    // Ordenar por última visita (más recientes primero)
    communitiesWithVisit.sort((a, b) {
      final DateTime aVisit =
          a['lastVisit'] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bVisit =
          b['lastVisit'] ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bVisit.compareTo(aVisit);
    });

    return communitiesWithVisit;
  }

  // Función para formatear el tiempo de última visita
  String _formatLastVisit(DateTime? lastVisit) {
    if (lastVisit == null) {
      return 'Nunca';
    }

    final now = DateTime.now();
    final difference = now.difference(lastVisit);

    if (difference.inDays < 1) {
      // Si es del mismo día, mostrar hora:minuto:segundo
      return DateFormat('HH:mm:ss').format(lastVisit);
    } else {
      // Si es de días anteriores, mostrar día/mes/año
      return DateFormat('dd/MM/yyyy').format(lastVisit);
    }
  }

  void _showJoinCommunityDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _JoinCommunityDialogContent(theme: theme);
      },
    );
  }

  Widget _buildDefaultAvatar(ThemeData theme) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.group, size: 32, color: theme.colorScheme.primary),
    );
  }

  Widget _buildCommunityListItem(
    BuildContext context,
    String title,
    String members,
    String communityId,
    String imageUrl,
    String privacy,
    String description,
    DateTime? lastVisit, {
    bool isLoading = false,
  }) {
    final theme = Theme.of(context);
    final lastVisitText = _formatLastVisit(lastVisit);

    return InkWell(
      onTap: () async {
        // Actualizar cache local INMEDIATAMENTE para UI responsiva
        setState(() {
          _lastVisitsCache[communityId] = DateTime.now();
          _needsRefresh = true;
        });

        // Actualizar en Firestore en background
        updateCommunityLastVisit(communityId);

        if (context.mounted) {
          final result = await Navigator.of(
            context,
          ).pushNamed('/communityDetail', arguments: {'id': communityId});

          // Cuando regrese, forzar actualización si es necesario
          if (result != null || _needsRefresh) {
            _refreshCommunities();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(theme);
                          },
                        )
                      : _buildDefaultAvatar(theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: fontFamilyPrimary,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          members,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: fontFamilyPrimary,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.purpleAccent.shade200.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: isLoading
                              ? Container(
                                  height: 12,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                )
                              : Text(
                                  lastVisitText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: fontFamilyPrimary,
                                    color: Colors.purpleAccent.shade200
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double maxContentWidth = screenWidth > 480 ? 480 : screenWidth - 32;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // My Communities Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 12.0),
              child: Text(
                "Mis Comunidades",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFamily: fontFamilyPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.015 * 22,
                  color: theme.colorScheme.onBackground,
                ),
              ),
            ),

            // Lista de Comunidades con actualización en tiempo real
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshCommunities();
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: StreamBuilder<QuerySnapshot>(
                  stream: _communitiesStream,
                  builder: (context, communitiesSnapshot) {
                    if (communitiesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cargando comunidades...',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (communitiesSnapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: theme.colorScheme.error.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error al cargar comunidades',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Por favor, intenta de nuevo',
                              style: TextStyle(
                                fontFamily: fontFamilyPrimary,
                                color: theme.colorScheme.onBackground
                                    .withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _refreshCommunities,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!communitiesSnapshot.hasData ||
                        communitiesSnapshot.data!.docs.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.2,
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.groups_outlined,
                                  size: 60,
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '¡No hay comunidades aún!',
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onBackground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Crea tu primera comunidad o únete a una existente',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: fontFamilyPrimary,
                                  fontSize: 16,
                                  color: theme.colorScheme.onBackground
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CreateCommunityScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  'Crear primera comunidad',
                                  style: TextStyle(
                                    fontFamily: fontFamilyPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    final communities = communitiesSnapshot.data!.docs;

                    // Segundo StreamBuilder para las últimas visitas - TIEMPO REAL
                    return StreamBuilder<QuerySnapshot>(
                      stream: _lastVisitsStream,
                      builder: (context, visitsSnapshot) {
                        // Construir mapa de últimas visitas
                        Map<String, DateTime> lastVisitsMap = {};
                        if (visitsSnapshot.hasData) {
                          for (var doc in visitsSnapshot.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final timestamp = data['timestamp'] as Timestamp?;
                            if (timestamp != null) {
                              lastVisitsMap[doc.id] = timestamp.toDate();
                            }
                          }
                        }

                        // Combinar con cache local y ordenar
                        final sortedCommunities = _sortCommunitiesWithCache(
                          communities,
                          lastVisitsMap,
                        );

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: sortedCommunities.length,
                          itemBuilder: (context, index) {
                            final communityInfo = sortedCommunities[index];
                            final communityData =
                                communityInfo['data'] as Map<String, dynamic>;
                            final communityId = communityInfo['id'] as String;
                            final lastVisit =
                                communityInfo['lastVisit'] as DateTime?;

                            final String name =
                                communityData['name'] ?? 'Sin nombre';
                            final String description =
                                communityData['description'] ?? '';
                            final String imageUrl =
                                communityData['imageUrl'] ?? '';
                            final int memberCount =
                                (communityData['members'] as List?)?.length ??
                                0;
                            final String privacy =
                                communityData['privacy'] ?? 'public';

                            return _buildCommunityListItem(
                              context,
                              name,
                              '$memberCount ${memberCount == 1 ? 'miembro' : 'miembros'}',
                              communityId,
                              imageUrl,
                              privacy,
                              description,
                              lastVisit,
                              isLoading:
                                  visitsSnapshot.connectionState ==
                                  ConnectionState.waiting,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Botones inferiores
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateCommunityScreen(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.group_add,
                            color: theme.colorScheme.onPrimary,
                          ),
                          label: Text(
                            "Crear Comunidad",
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.6),
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 56,
                        child: TextButton.icon(
                          onPressed: () {
                            _showJoinCommunityDialog(context);
                          },
                          icon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(
                            "Unirse a Comunidad",
                            style: TextStyle(
                              fontFamily: fontFamilyPrimary,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Función global para actualizar la última visita
Future<void> updateCommunityLastVisit(String communityId) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('lastVisits')
        .doc(communityId)
        .set({
          'timestamp': FieldValue.serverTimestamp(),
          'communityId': communityId,
        }, SetOptions(merge: true));
  } catch (e) {
    print('Error actualizando última visita: $e');
  }
}

class _JoinCommunityDialogContent extends StatefulWidget {
  final ThemeData theme;

  const _JoinCommunityDialogContent({required this.theme});

  @override
  _JoinCommunityDialogContentState createState() =>
      _JoinCommunityDialogContentState();
}

class _JoinCommunityDialogContentState
    extends State<_JoinCommunityDialogContent> {
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.search, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Text(
            'Unirse',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Introduce el código de invitación de la comunidad:',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: theme.colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: TextField(
              controller: _codeController,
              decoration: InputDecoration(
                hintText: 'ej. TECH2024',
                hintStyle: TextStyle(
                  fontFamily: fontFamilyPrimary,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                prefixIcon: Icon(Icons.key, color: theme.colorScheme.primary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: TextStyle(
                fontFamily: fontFamilyPrimary,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            'Cancelar',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            final code = _codeController.text.trim();
            final user = FirebaseAuth.instance.currentUser;

            if (user == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Debes iniciar sesión para unirte a una comunidad.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              if (context.mounted) Navigator.of(context).pop();
              return;
            }

            if (code.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor, introduce un código de invitación.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }

            try {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('communities')
                  .where('joinCode', isEqualTo: code.toUpperCase())
                  .limit(1)
                  .get();

              if (querySnapshot.docs.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Código de invitación no válido o comunidad no encontrada.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              } else {
                final communityDoc = querySnapshot.docs.first;
                final communityId = communityDoc.id;
                final communityData =
                    communityDoc.data() as Map<String, dynamic>;
                final List<dynamic> currentMembers =
                    communityData['members'] ?? [];
                final String communityName =
                    communityData['name'] ?? 'la comunidad';

                if (currentMembers.contains(user.uid)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ya eres miembro de $communityName.'),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('communities')
                      .doc(communityId)
                      .update({
                        'members': FieldValue.arrayUnion([user.uid]),
                      });

                  // Actualizar última visita al unirse
                  await updateCommunityLastVisit(communityId);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '¡Te has unido a $communityName exitosamente!',
                        ),
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  }
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al unirse a la comunidad: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } finally {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Unirse',
            style: TextStyle(
              fontFamily: fontFamilyPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
