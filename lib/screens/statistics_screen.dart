import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/routine.dart';
import '../providers/auth_provider.dart';
import '../services/routine_service.dart';
import '../widgets/routines/create_routine_form.dart';
import '../widgets/routines/routine_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Routine> _routines = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();

      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = tr('token_not_found_login');
        });
        return;
      }

      final service = RoutineService(token: token);
      final result = await service.getUserRoutines();

      if (result['success'] == true) {
        setState(() {
          _routines = List<Routine>.from(
            result['routines'].map((x) => Routine.fromJson(x)),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? tr('error_loading_routines');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${tr('error')}: $e';
      });
    }
  }

  void _showCreateRoutineModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRoutineForm(
        onRoutineCreated: _loadRoutines,
      ),
    );
  }

  void _showEditRoutineModal(Routine routine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateRoutineForm(
        routineToEdit: routine,
        onRoutineCreated: _loadRoutines,
      ),
    );
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(tr('delete_routine_title'),
            style: TextStyle(color: Colors.white)),
        content: Text(tr('delete_routine_confirmation'),
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel'), style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = await auth.getToken();
      if (token != null) {
        final service = RoutineService(token: token);
        final result = await service.deleteRoutine(routine.id!);
        if (result['success'] == true) {
          _loadRoutines();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(result['message'] ?? tr('error_deleting_routine'))),
          );
        }
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'RUTINAS',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              tr('routine_empty_description'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showCreateRoutineModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                tr('create').toUpperCase(),
                style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutinesList() {
    return RefreshIndicator(
      onRefresh: _loadRoutines,
      child: _routines.isEmpty
          ? ListView(
              // Necesitamos un ListView para que RefreshIndicator funcione incluso con pocos items
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              children: _routines
                  .map(
                    (routine) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: RoutineCard(
                        routine: routine,
                        onEdit: () => _showEditRoutineModal(routine),
                        onDelete: () => _deleteRoutine(routine),
                      ),
                    ),
                  )
                  .toList(),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _routines.length,
              itemBuilder: (context, index) {
                final routine = _routines[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: RoutineCard(
                    routine: routine,
                    onEdit: () => _showEditRoutineModal(routine),
                    onDelete: () => _deleteRoutine(routine),
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(tr('routines')),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _routines.isEmpty
                  ? _buildEmptyState()
                  : _buildRoutinesList(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          onPressed: _showCreateRoutineModal,
          backgroundColor: Colors.white,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
