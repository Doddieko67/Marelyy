import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';
import 'package:classroom_mejorado/core/services/trash_service.dart';

class TrashManagementScreen extends StatefulWidget {
  final String? communityId;
  
  const TrashManagementScreen({super.key, this.communityId});

  @override
  State<TrashManagementScreen> createState() => _TrashManagementScreenState();
}

class _TrashManagementScreenState extends State<TrashManagementScreen> {
  final TrashService _trashService = TrashService();
  String _selectedFilter = 'all';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          widget.communityId != null ? 'Papelera de la Comunidad' : 'Papelera Global',
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.cleaning_services, color: theme.colorScheme.primary),
            onPressed: _showCleanupDialog,
            tooltip: 'Limpiar archivos expirados',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          _buildFilterChips(theme),
          
          // Lista de archivos en papelera
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _trashService.getTrashFiles(
                communityId: widget.communityId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                final trashFiles = snapshot.data ?? [];
                final filteredFiles = _filterFiles(trashFiles);

                if (filteredFiles.isEmpty) {
                  return _buildEmptyState(theme);
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filteredFiles.length,
                  itemBuilder: (context, index) {
                    return _buildTrashFileCard(context, filteredFiles[index], theme);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showStatsDialog,
        icon: Icon(Icons.analytics),
        label: Text('Estadísticas'),
        backgroundColor: theme.colorScheme.secondary,
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final filters = [
      {'key': 'all', 'label': 'Todos', 'icon': Icons.all_inclusive},
      {'key': 'image', 'label': 'Imágenes', 'icon': Icons.image},
      {'key': 'document', 'label': 'Documentos', 'icon': Icons.description},
      {'key': 'video', 'label': 'Videos', 'icon': Icons.video_file},
      {'key': 'audio', 'label': 'Audio', 'icon': Icons.audio_file},
    ];

    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: isSelected 
                        ? theme.colorScheme.onPrimary 
                        : theme.colorScheme.onSurface,
                  ),
                  SizedBox(width: 4),
                  Text(filter['label'] as String),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrashFileCard(BuildContext context, Map<String, dynamic> fileData, ThemeData theme) {
    final fileName = fileData['fileName'] as String? ?? 'Archivo sin nombre';
    final fileType = fileData['type'] as String? ?? 'file';
    final deletedBy = fileData['deletedByName'] as String? ?? 'Usuario desconocido';
    final deletedAt = fileData['deletedAt'] as dynamic;
    final autoDeleteAt = fileData['autoDeleteAt'] as dynamic;
    
    DateTime? deletedDate;
    DateTime? expiryDate;
    
    if (deletedAt != null) {
      deletedDate = (deletedAt as Timestamp).toDate();
    }
    
    if (autoDeleteAt != null) {
      expiryDate = (autoDeleteAt as Timestamp).toDate();
    }

    final daysUntilExpiry = expiryDate != null 
        ? expiryDate.difference(DateTime.now()).inDays 
        : null;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(fileType),
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontFamily: fontFamilyPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Eliminado por: $deletedBy',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      if (deletedDate != null) ...[
                        SizedBox(height: 2),
                        Text(
                          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(deletedDate)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (daysUntilExpiry != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: daysUntilExpiry <= 7 
                      ? Colors.red.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  daysUntilExpiry <= 0 
                      ? 'Expirado'
                      : 'Expira en $daysUntilExpiry días',
                  style: TextStyle(
                    color: daysUntilExpiry <= 7 ? Colors.red : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _restoreFile(fileData['id']),
                  icon: Icon(Icons.restore, size: 16),
                  label: Text('Restaurar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deletePermanently(fileData['id'], fileName),
                  icon: Icon(Icons.delete_forever, size: 16),
                  label: Text('Eliminar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Text(
            'Papelera vacía',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Los archivos eliminados aparecerán aquí',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterFiles(List<Map<String, dynamic>> files) {
    if (_selectedFilter == 'all') return files;
    return files.where((file) => file['type'] == _selectedFilter).toList();
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'document':
        return Icons.description;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _restoreFile(String trashDocId) async {
    try {
      final success = await _trashService.restoreFile(trashDocId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo restaurado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('No se pudo restaurar el archivo');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restaurando archivo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePermanently(String trashDocId, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar permanentemente'),
        content: Text(
          '¿Estás seguro de que deseas eliminar permanentemente "$fileName"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _trashService.deletePermanently(trashDocId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Archivo eliminado permanentemente'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          throw Exception('No se pudo eliminar el archivo');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error eliminando archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCleanupDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpiar archivos expirados'),
        content: Text(
          '¿Deseas eliminar permanentemente todos los archivos que han expirado?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _trashService.cleanExpiredFiles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Limpieza completada'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante la limpieza: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showStatsDialog() async {
    try {
      final stats = await _trashService.getTrashStats(
        communityId: widget.communityId,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Estadísticas de la Papelera'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total de archivos: ${stats['totalFiles']}'),
              SizedBox(height: 8),
              Text('Archivos por tipo:'),
              ...((stats['filesByType'] as Map<String, int>).entries.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(left: 16, top: 4),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error obteniendo estadísticas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}