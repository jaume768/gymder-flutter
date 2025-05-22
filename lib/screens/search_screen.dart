import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../providers/auth_provider.dart';
import 'user_profile_screen.dart';
import '../widgets/custom_app_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/constants.dart'; // For AppColors or other constants

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<User> _users = [];
  bool _isLoading = false;
  bool _isLoadMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String _currentSearchTerm = '';
  String? _error;

  UserService? _userService; // Made nullable

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.getToken().then((t) {
      if (t != null) {
        setState(() {
          _userService = UserService(token: t);
        });
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadMore &&
        _hasMore &&
        !_isLoading) {
      _loadMoreUsers();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim() != _currentSearchTerm) {
        _currentSearchTerm = query.trim();
        if (_currentSearchTerm.isEmpty) {
          setState(() {
            _users = [];
            _isLoading = false;
            _error = null;
            _hasMore = true; // Reset for next search
            _currentPage = 1;
          });
          return;
        }
        _fetchUsers(isNewSearch: true);
      }
    });
  }

  Future<void> _fetchUsers({bool isNewSearch = false}) async {
    if (!mounted) return;

    if (_userService == null) { // Added null check
      setState(() {
        _isLoading = false;
        _isLoadMore = false;
        _error = 'user_service_not_initialized'.tr();
      });
      return;
    }

    if (isNewSearch) {
      setState(() {
        _isLoading = true;
        _users = [];
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoadMore = true;
      });
    }

    try {
      final result = await _userService!.searchUsers( // Added ! operator
        term: _currentSearchTerm,
        page: _currentPage,
        limit: 20,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final List<User> fetchedUsers = result['users'] ?? [];
        setState(() {
          if (isNewSearch) {
            _users = fetchedUsers;
          } else {
            _users.addAll(fetchedUsers);
          }
          _hasMore = result['hasMore'] ?? false;
          if (fetchedUsers.isNotEmpty && !isNewSearch) {
            _currentPage++;
          }
          _error = null;
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to search users';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred: ${e.toString()}';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadMore = false;
      });
    }
  }

  void _loadMoreUsers() {
    if (_hasMore && !_isLoading && !_isLoadMore) {
      _fetchUsers(isNewSearch: false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'search_hint'.tr(),
          prefixIcon: Icon(Icons.search, color: Theme.of(context).iconTheme.color),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Theme.of(context).iconTheme.color),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
          ),
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }

  Widget _buildUserListItem(User user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (user.profilePicture?.url != null && user.profilePicture!.url.isNotEmpty)
            ? NetworkImage(user.profilePicture!.url)
            : null,
        child: (user.profilePicture?.url == null || user.profilePicture!.url.isEmpty)
            ? Icon(Icons.person, color: Colors.grey[400])
            : null,
        backgroundColor: Colors.grey[700],
      ),
      title: Row(
        children: [
          Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (user.verificationStatus == 'true')
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Icon(Icons.verified, color: AppColors.azulLetras, size: 16),
            ),
        ],
      ),
      subtitle: Text('${user.firstName ?? ''} ${user.lastName ?? ''}'.trim()),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: user.id),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'search_users_title'.tr()),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('error_occurred'.tr() + ': $_error'));
    }
    if (_users.isEmpty && _currentSearchTerm.isNotEmpty && !_isLoading) {
      return Center(child: Text('no_users_found_for'.tr(args: [_currentSearchTerm])));
    }
    if (_users.isEmpty && _currentSearchTerm.isEmpty) {
      return Center(child: Text('search_for_users_prompt'.tr()));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _users.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return _isLoadMore
              ? const Center(child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ))
              : const SizedBox.shrink();
        }
        final user = _users[index];
        return _buildUserListItem(user);
      },
    );
  }
}