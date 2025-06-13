import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:classroom_mejorado/core/constants/app_typography.dart';

class QuickStatsWidget extends StatelessWidget {
  const QuickStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('tasks')
          .where('assignedToId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final tasks = snapshot.data!.docs;
        final totalTasks = tasks.length;
        final completedTasks = tasks.where((task) {
          final data = task.data() as Map<String, dynamic>;
          final state = data['state'] as String? ?? '';
          return state.toLowerCase() == 'done' || state.toLowerCase() == 'completed';
        }).length;
        
        final overdueTasks = tasks.where((task) {
          final data = task.data() as Map<String, dynamic>;
          final state = data['state'] as String? ?? '';
          final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
          
          return dueDate != null && 
                 dueDate.isBefore(DateTime.now()) && 
                 state.toLowerCase() != 'done' && 
                 state.toLowerCase() != 'completed';
        }).length;
        
        final completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.8),
                theme.colorScheme.secondary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
   const SizedBox(height: 16),
              
              // Progress bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: completionRate / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      '📋',
                      totalTasks.toString(),
                      'Total',
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      '✅',
                      completedTasks.toString(),
                      'Completadas',
                    ),
                  ),
                  if (overdueTasks > 0)
                    Expanded(
                      child: _buildStatItem(
                        '⚠️',
                        overdueTasks.toString(),
                        'Vencidas',
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: fontFamilyPrimary,
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}