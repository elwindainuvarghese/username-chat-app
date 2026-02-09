import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF3B3B3B),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: const Center(
        child: Text(
          'Search Screen',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B1B3A),
          ),
        ),
      ),
    );
  }
}
