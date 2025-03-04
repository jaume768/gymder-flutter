import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/user_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<User> blockedUsers = [];
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      isLoading = true;
      error = '';
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) throw Exception(tr("token_not_found"));
      final userService = UserService(token: token);
      final users = await userService.getBlockedUsers();
      setState(() {
        blockedUsers = users;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getToken();
      if (token == null) throw Exception(tr("token_not_found"));
      final userService = UserService(token: token);
      final result = await userService.unblockUser(userId);
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? tr("user_unblocked"))),
        );
        setState(() {
          blockedUsers.removeWhere((user) => user.id == userId);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? tr("error_unblocking_user"))),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("error") + ": $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr("blocked_users")),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.grey[900],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(
                  child: Text(error,
                      style: const TextStyle(color: Colors.redAccent)))
              : blockedUsers.isEmpty
                  ? Center(
                      child: Text(tr("no_blocked_users"),
                          style: const TextStyle(color: Colors.white)),
                    )
                  : ListView.builder(
                      itemCount: blockedUsers.length,
                      itemBuilder: (context, index) {
                        final blockedUser = blockedUsers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: blockedUser.profilePicture != null
                                ? NetworkImage(blockedUser.profilePicture!.url)
                                : const AssetImage(
                                        'assets/images/default_profile.png')
                                    as ImageProvider,
                          ),
                          title: Text(blockedUser.username,
                              style: const TextStyle(color: Colors.white)),
                          trailing: ElevatedButton(
                            onPressed: () => _unblockUser(blockedUser.id),
                            child: Text(tr("unblock")),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green),
                          ),
                        );
                      },
                    ),
    );
  }
}
