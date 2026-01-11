import 'package:flutter/material.dart';

import '../../../../core/services/auth_service.dart';
import '../../../../core/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _playerIdController = TextEditingController(); // Read-only

  bool _isLoading = true;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      _uid = user.uid;
      try {
        final doc = await _firestoreService.getUser(user.uid);
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          _nameController.text = data['displayName'] ?? user.displayName ?? '';
          _playerIdController.text = data['playerId'] ?? 'Generating...';
        } else {
             _nameController.text = user.displayName ?? '';
             _playerIdController.text = 'Pending...';
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading profile: $e')),
          );
        }
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_uid == null) return;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.updateUserName(_uid!, _nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _playerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _playerIdController,
                    decoration: const InputDecoration(
                      labelText: 'Player ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                      filled: true,
                      fillColor: Colors.black12, // Visual cue for read-only
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                      helperText: 'This name will be visible to other players',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'SAVE CHANGES',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
