import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import 'product_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArkaColors.cream,
        foregroundColor: ArkaColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: TextField(
          controller: _text,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Ringe, Ketten, Ohrringe …',
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _text.clear();
                setState(() => _query = '');
              },
            ),
          ),
        ),
      ),
      body: _query.length < 2
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Wonach suchst du?', style: TextStyle(color: ArkaColors.muted, fontSize: 16)),
              ),
            )
          : PagedProductGrid(key: ValueKey(_query), search: _query, showSort: false),
    );
  }
}
