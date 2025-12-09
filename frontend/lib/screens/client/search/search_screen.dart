import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../config/theme.dart';
import '../../../providers/cafe_provider.dart';
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
    final searchResults = ref.watch(searchCafesProvider(_searchQuery));

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
              hint: 'Search cafes, games...',
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

          // Popular Searches (when no query)
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Popular Games',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SearchChip(label: 'Valorant', onTap: () => _performSearch('Valorant')),
                      _SearchChip(label: 'CS2', onTap: () => _performSearch('CS2')),
                      _SearchChip(label: 'GTA V', onTap: () => _performSearch('GTA')),
                      _SearchChip(label: 'Fortnite', onTap: () => _performSearch('Fortnite')),
                      _SearchChip(label: 'FIFA 24', onTap: () => _performSearch('FIFA')),
                      _SearchChip(label: 'Call of Duty', onTap: () => _performSearch('COD')),
                    ],
                  ),
                ],
              ),
            ),

          // Search Results
          Expanded(
            child: _searchQuery.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 64, color: AppColors.textMuted),
                        SizedBox(height: 16),
                        Text(
                          'Search for cafes or games',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : searchResults.when(
                    data: (cafes) {
                      if (cafes.isEmpty) {
                        return EmptyState(
                          icon: Icons.search_off,
                          title: 'No results found',
                          subtitle: 'Try a different search term',
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cafes.length,
                        itemBuilder: (context, index) {
                          final cafe = cafes[index];
                          return CafeCard(
                            cafe: cafe,
                            showDistance: false,
                            onTap: () => context.push('/client/cafe/${cafe.id}'),
                          );
                        },
                      );
                    },
                    loading: () => ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 3,
                      itemBuilder: (context, index) => const ShimmerCafeCard(),
                    ),
                    error: (error, stack) => ErrorDisplay(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(searchCafesProvider(_searchQuery)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardDark),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

