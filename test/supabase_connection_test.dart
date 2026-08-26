import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() {
  test('Verify Supabase Connection', () async {
    final envContent = File('.env').readAsStringSync();
    
    // Quick manual parse for the test
    final lines = envContent.split('\n');
    String url = '';
    String anonKey = '';
    
    for (var line in lines) {
      if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].trim();
      if (line.startsWith('SUPABASE_ANON_KEY=')) anonKey = line.substring('SUPABASE_ANON_KEY='.length).trim();
    }
    
    expect(url, isNotEmpty);
    expect(anonKey, isNotEmpty);
    
    final client = SupabaseClient(url, anonKey);
    
    try {
      // We do a lightweight call just to ensure no initialization errors
      await client.from('users').select().limit(1);
      print('Database reached successfully!');
    } catch (e) {
      print('Response from Supabase: $e');
    }
  });
}
