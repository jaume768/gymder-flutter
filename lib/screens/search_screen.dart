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
import 'package:cached_network_image/cached_network_image.dart';

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
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
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
        
        // Si está vacío, limpia los resultados
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
        
        // Verifica que haya al menos 3 caracteres para iniciar la búsqueda
        if (_currentSearchTerm.length >= 3) {
          _fetchUsers(isNewSearch: true);
        } else if (_users.isNotEmpty) {
          // Si hay menos de 3 caracteres y ya hay resultados, limpia los resultados
          setState(() {
            _users = [];
            _error = null;
            _hasMore = true;
            _currentPage = 1;
          });
        }
      }
    });
  }

  Future<void> _fetchUsers({bool isNewSearch = false}) async {
    if (!mounted) return;

    if (_userService == null) {
      // Added null check
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
      final result = await _userService!.searchUsers(
        // Added ! operator
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'search_hint'.tr(),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[850],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide(color: AppColors.azulLetras, width: 1.5),
          ),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildUserListItem(User user) {
    return Card(
      color: Colors.grey[850],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12.0),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[700],
          backgroundImage: (user.profilePicture?.url != null &&
                  user.profilePicture!.url.isNotEmpty)
              ? CachedNetworkImageProvider(user.profilePicture!.url)
              : null,
          child: (user.profilePicture?.url == null ||
                  user.profilePicture!.url.isEmpty)
              ? const Icon(Icons.person, color: Colors.white70, size: 25)
              : null,
        ),
        title: Row(
          children: [
            Text(user.username,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16)),
            if (user.verificationStatus == 'true')
              Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child:
                    Icon(Icons.verified, color: AppColors.azulLetras, size: 16),
              ),
          ],
        ),
        subtitle: Text(
          '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
          style: const TextStyle(color: Colors.white70),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: user.id),
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
        title: Text('search_users_title'.tr()),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
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
      return const Center(
          child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.azulLetras),
        strokeWidth: 3,
        backgroundColor: Color(0xFF303030),
      ));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'error_occurred'.tr() + ': $_error',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_users.isEmpty && _currentSearchTerm.isNotEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              color: Colors.white54,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'no_users_found_for'.tr(args: [_currentSearchTerm]),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_users.isEmpty && _currentSearchTerm.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              color: Colors.white54,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'search_for_users_prompt'.tr(),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Muestra un mensaje cuando hay menos de 3 caracteres
    if (_users.isEmpty && _currentSearchTerm.isNotEmpty && _currentSearchTerm.length < 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              color: Colors.white54,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              tr('type_at_least_3_characters'),
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: _users.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _users.length) {
          return _isLoadMore
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.azulLetras),
                    strokeWidth: 3,
                  ),
                ))
              : const SizedBox.shrink();
        }
        final user = _users[index];
        return _buildUserListItem(user);
      },
    );
  }
}
