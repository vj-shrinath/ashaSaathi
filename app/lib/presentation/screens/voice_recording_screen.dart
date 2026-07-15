import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceRecordingScreen extends StatefulWidget {
  final String patientId;
  const VoiceRecordingScreen({super.key, required this.patientId});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  bool _isRecording = false;
  bool _isProcessing = false;
  String? get _ashaId => Supabase.instance.client.auth.currentUser?.id;

  // In production, use `record` or `flutter_sound` package to get actual mic bytes.
  // For safety in this MVP layer, we mock the Audio Buffer to avoid native iOS/Android mic permission crashes.

  Future<void> _mockRecordAndUpload() async {
    if (_ashaId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in again to record a visit.')),
        );
      }
      return;
    }

    setState(() => _isRecording = true);
    
    // Simulate recording time
    await Future.delayed(const Duration(seconds: 3));
    
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    try {
      // In production, this points to your Node.js backend (e.g. Google Cloud Run URL)
      // We simulate the multipart request.
      
      /*
      var request = http.MultipartRequest('POST', Uri.parse('https://api.ashasaathi.com/v1/visit/process-audio'));
      request.fields['patientId'] = widget.patientId;
      request.fields['ashaId'] = 'current_user_id';
      request.files.add(await http.MultipartFile.fromPath('audioFile', 'path/to/local/audio.wav'));
      
      var response = await request.send();
      if (response.statusCode == 200) { ... }
      */

      // Simulate network lag to backend
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI Visit processed and saved successfully!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Visit')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Press to start speaking in Hindi',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            
            if (_isProcessing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading to Saaras AI & Claude...'),
                ],
              )
            else
              GestureDetector(
                onTap: _mockRecordAndUpload,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isRecording ? 140 : 120,
                  height: _isRecording ? 140 : 120,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_isRecording) 
                        BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 10)
                    ]
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 60),
                ),
              ),

             const SizedBox(height: 40),
             if (_isRecording) const Text('Recording...', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
