import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../config/theme.dart';
import '../../../providers/cafe_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/cafe_card.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/input_field.dart';

/// Search Screen
class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Debounce timer for search optimization
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _searchQuery = widget.initialQuery!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _performSearch(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Set new timer for debounced search (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(allCafesWithDistanceProvider(_searchQuery));
    final locationState = ref.watch(locationProvider);

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.trueBlack,
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchField(
              controller: _searchController,
              hint: 'Search cafes by name...',
              autofocus: widget.initialQuery == null,
              onChanged: (value) {
                if (value.length >= 2 || value.isEmpty) {
                  _performSearch(value);
                }
              },
              onSubmitted: _performSearch,
              onClear: () => _performSearch(''),
            ),
          ),

          // Search Results - Always show cafes sorted by distance
          Expanded(
            child: locationState.location == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off, size: 64, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'Location Required',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enable location to find cafes near you',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => ref
                              .read(locationProvider.notifier)
                              .getCurrentLocation(),
                          icon: const Icon(Icons.my_location),
                          label: const Text('Enable Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.cyberCyan,
                            foregroundColor: AppColors.trueBlack,
                          ),
                        ),
                      ],
                    ),
                  )
                : searchResults.when(
                    data: (cafes) {
                      if (cafes.isEmpty) {
                        return EmptyState(
                          icon: _searchQuery.isEmpty ? Icons.store_outlined : Icons.search_off,
                          title: _searchQuery.isEmpty 
                              ? 'No cafes nearby' 
                              : 'No results found',
                          subtitle: _searchQuery.isEmpty
                              ? 'Try expanding your search area'
                              : 'Try a different search term',
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 80, // Account for bottom nav
                        ),
                        itemCount: cafes.length,
                        itemBuilder: (context, index) {
                          final cafe = cafes[index];
                          return CafeCard(
                            cafe: cafe,
                            showDistance: true,
                            onTap: () => context.push('/client/cafe/${cafe.id}'),
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 80, // Account for bottom nav
                      ),
                      itemCount: 3,
                      itemBuilder: (context, index) => const ShimmerCafeCard(),
                    ),
                    error: (error, stack) => ErrorDisplay(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(allCafesWithDistanceProvider(_searchQuery)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

