import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const VibeCourtApp());
}

class VibeCourtApp extends StatelessWidget {
  const VibeCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF120F19);
    const paper = Color(0xFFF4E7CF);
    const gold = Color(0xFFE1A04B);
    const teal = Color(0xFF8CC9BE);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vibe Court',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: teal,
          surface: Color(0xFF1B1626),
          error: Color(0xFFFF8E7E),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 40,
            height: 1.02,
            fontWeight: FontWeight.w800,
            color: paper,
            letterSpacing: -1.2,
          ),
          headlineSmall: TextStyle(
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: paper,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: paper,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: paper,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Color(0xFFD7D0DC),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFFA79DB0),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1522),
          hintStyle: const TextStyle(color: Color(0xFF7F738C)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFF3D3346)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: Color(0xFF3D3346)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: gold, width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      home: const AnalysisPage(),
    );
  }
}

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final _calendarController = TextEditingController();
  final _musicController = TextEditingController();
  final _apiController = TextEditingController(text: 'http://10.0.2.2:8000');
  final _picker = ImagePicker();

  File? _calendarPhoto;
  File? _roomPhoto;
  bool _submitting = false;
  String? _error;
  CourtResult? _result;

  @override
  void dispose() {
    _calendarController.dispose();
    _musicController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _pickRoomPhoto() async {
    final picked = await _pickImage();
    if (picked == null) return;
    setState(() {
      _roomPhoto = File(picked.path);
    });
  }

  Future<void> _pickCalendarPhoto() async {
    final picked = await _pickImage();
    if (picked == null) return;
    setState(() {
      _calendarPhoto = File(picked.path);
    });
  }

  Future<XFile?> _pickImage() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
  }

  Future<_EncodedImage?> _encodeImage(File? file) async {
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final path = file.path.toLowerCase();
    var mimeType = 'image/jpeg';
    if (path.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (path.endsWith('.webp')) {
      mimeType = 'image/webp';
    }
    return _EncodedImage(
      base64Data: base64Encode(bytes),
      mimeType: mimeType,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
      _result = null;
    });

    try {
      final calendarImage = await _encodeImage(_calendarPhoto);
      final roomImage = await _encodeImage(_roomPhoto);

      final response = await http.post(
        Uri.parse('${_apiController.text.trim()}/api/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'calendar_text': _calendarController.text.trim(),
          'calendar_image_base64': calendarImage?.base64Data,
          'calendar_image_mime_type': calendarImage?.mimeType ?? 'image/jpeg',
          'recently_played_text': _musicController.text.trim(),
          'room_image_base64': roomImage?.base64Data,
          'room_image_mime_type': roomImage?.mimeType ?? 'image/jpeg',
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw Exception(_extractError(data));
      }

      setState(() {
        _result = CourtResult.fromJson(data['result'] as Map<String, dynamic>);
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _submitting = false;
      });
    }
  }

  String _extractError(Map<String, dynamic> data) {
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    return 'Request failed. Check your backend URL and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF17121F),
              Color(0xFF120F19),
              Color(0xFF0D0A12),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TopBar(),
                const SizedBox(height: 18),
                const _HeroCard(),
                const SizedBox(height: 18),
                _CommandCard(
                  controller: _apiController,
                ),
                const SizedBox(height: 18),
                _EvidenceCard(
                  indexLabel: 'Exhibit A',
                  icon: Icons.calendar_month_rounded,
                  title: 'Calendar Evidence',
                  subtitle: 'Scheduling habits, fake urgency, and suspicious use of 30-minute blocks.',
                  textField: TextField(
                    controller: _calendarController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          'Mon 09:00 standup\nMon 10:00 product sync\nTue 23:30 quick planning session\nWed 07:00 gym that absolutely will not happen',
                    ),
                  ),
                  photo: _calendarPhoto,
                  emptyPhotoLabel: 'Attach calendar screenshot',
                  filledPhotoLabel: 'Change calendar screenshot',
                  onPickPhoto: _pickCalendarPhoto,
                ),
                const SizedBox(height: 16),
                _EvidenceCard(
                  indexLabel: 'Exhibit B',
                  icon: Icons.graphic_eq_rounded,
                  title: 'Recently Played',
                  subtitle: 'Music taste is evidence. The court accepts playlists, loops, and emotional relapse.',
                  textField: TextField(
                    controller: _musicController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText:
                          '1. Charli xcx - Von dutch\n2. Frank Ocean - Nights\n3. Aphex Twin - Avril 14th\n4. NewJeans - Ditto',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _EvidenceCard(
                  indexLabel: 'Exhibit C',
                  icon: Icons.bedroom_parent_rounded,
                  title: 'Room Picture',
                  subtitle: 'One room photo says more than a polished bio ever will.',
                  photo: _roomPhoto,
                  emptyPhotoLabel: 'Attach room photo',
                  filledPhotoLabel: 'Change room photo',
                  onPickPhoto: _pickRoomPhoto,
                ),
                const SizedBox(height: 20),
                _ActionPanel(
                  submitting: _submitting,
                  onSubmit: _submit,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 22),
                  _ResultCard(result: _result!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFE1A04B), Color(0xFF7D2338)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x552D0F18),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(Icons.gavel_rounded, color: Color(0xFFF8EAD7)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Premium Roast Engine',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE1A04B),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'Vibe Court',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C1F31),
            Color(0xFF231929),
            Color(0xFF14101D),
          ],
        ),
        border: Border.all(color: const Color(0xFF493040)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -8,
            child: Container(
              height: 120,
              width: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x55E1A04B), Color(0x00E1A04B)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0x26F4E7CF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Submit evidence. Receive judgment.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFF4E7CF),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Your schedule,\nplaylist, and room\nare now on trial.',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'A premium AI verdict that feels sharp enough to share and honest enough to sting.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FeatureChip(label: 'Courtroom verdict'),
                  _FeatureChip(label: 'Taste + chaos score'),
                  _FeatureChip(label: 'Useful recommendation'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_tethering_rounded, color: Color(0xFFE1A04B)),
              const SizedBox(width: 10),
              Text('Court Connection', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use `10.0.2.2` on Android emulator and `127.0.0.1` on iOS simulator.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'http://10.0.2.2:8000',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.indexLabel,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.textField,
    this.photo,
    this.emptyPhotoLabel,
    this.filledPhotoLabel,
    this.onPickPhoto,
  });

  final String indexLabel;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? textField;
  final File? photo;
  final String? emptyPhotoLabel;
  final String? filledPhotoLabel;
  final VoidCallback? onPickPhoto;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2034),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFFE1A04B)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      indexLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFE1A04B),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          if (textField != null) ...[
            const SizedBox(height: 16),
            textField!,
          ],
          if (onPickPhoto != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onPickPhoto,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(photo == null ? emptyPhotoLabel! : filledPhotoLabel!),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF4E7CF),
                side: const BorderSide(color: Color(0xFF53455F)),
                backgroundColor: const Color(0xFF17121F),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
          if (photo != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Image.file(
                    photo!,
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xB3110E18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Evidence attached',
                        style: TextStyle(
                          color: Color(0xFFF4E7CF),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.submitting,
    required this.onSubmit,
  });

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF201927), Color(0xFF181320)],
        ),
        border: Border.all(color: const Color(0xFF3C3345)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Court Session', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Expect a verdict, charges, scorecard, and one useful fix.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE1A04B),
              foregroundColor: const Color(0xFF17131F),
              minimumSize: const Size(150, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(submitting ? 'In session...' : 'Open the case'),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1920),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF83404A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.report_gmailerrorred_rounded, color: Color(0xFFFFA89B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFFC7BE),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CourtResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: const Color(0xFFF1E3C8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2C000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF211722), height: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Final Verdict',
                        style: TextStyle(
                          color: Color(0xFF7D2338),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.caseTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF211722),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.oneLiner,
                        style: const TextStyle(
                          color: Color(0xFF7D2338),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF211722),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.balance_rounded, color: Color(0xFFF4E7CF)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              result.summary,
              style: const TextStyle(
                color: Color(0xFF443447),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ScoreChip(label: 'Chaos', value: result.scores.chaos),
                _ScoreChip(label: 'Taste', value: result.scores.taste),
                _ScoreChip(label: 'Discipline', value: result.scores.discipline),
                _ScoreChip(
                  label: 'Main Character',
                  value: result.scores.mainCharacter,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _ResultSectionTitle('Charges Filed'),
            const SizedBox(height: 12),
            ...result.charges.map(
              (charge) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChargeTile(charge: charge),
              ),
            ),
            const SizedBox(height: 8),
            const _ResultSectionTitle('Evidence'),
            const SizedBox(height: 10),
            ...result.evidence.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: Color(0xFF7D2338),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(color: Color(0xFF443447)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _VerdictStrip(
              title: 'Verdict',
              text: result.verdict,
              accent: const Color(0xFF7D2338),
            ),
            const SizedBox(height: 12),
            _VerdictStrip(
              title: 'Sentence',
              text: result.sentence,
              accent: const Color(0xFFE1A04B),
            ),
            const SizedBox(height: 12),
            _VerdictStrip(
              title: 'Recommendation',
              text: result.recommendation,
              accent: const Color(0xFF2F7F74),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF191420),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF31283B)),
      ),
      child: child,
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1FF4E7CF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF4E7CF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D0AE)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF211722),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7C6B70),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeTile extends StatelessWidget {
  const _ChargeTile({required this.charge});

  final Charge charge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3D0AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF211722),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${charge.severity}/10',
              style: const TextStyle(
                color: Color(0xFFF4E7CF),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  charge.title,
                  style: const TextStyle(
                    color: Color(0xFF211722),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  charge.detail,
                  style: const TextStyle(color: Color(0xFF4C3B50)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSectionTitle extends StatelessWidget {
  const _ResultSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF211722),
        fontWeight: FontWeight.w800,
        fontSize: 17,
      ),
    );
  }
}

class _VerdictStrip extends StatelessWidget {
  const _VerdictStrip({
    required this.title,
    required this.text,
    required this.accent,
  });

  final String title;
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.45),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(color: Color(0xFF4A384D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CourtResult {
  CourtResult({
    required this.caseTitle,
    required this.oneLiner,
    required this.summary,
    required this.charges,
    required this.evidence,
    required this.verdict,
    required this.sentence,
    required this.scores,
    required this.recommendation,
  });

  final String caseTitle;
  final String oneLiner;
  final String summary;
  final List<Charge> charges;
  final List<String> evidence;
  final String verdict;
  final String sentence;
  final ScoreCard scores;
  final String recommendation;

  factory CourtResult.fromJson(Map<String, dynamic> json) {
    return CourtResult(
      caseTitle: json['case_title'] as String? ?? 'The People v. Your Vibe',
      oneLiner: json['one_liner'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      charges: ((json['charges'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>())
          .map(Charge.fromJson)
          .toList(),
      evidence: (json['evidence'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      verdict: json['verdict'] as String? ?? '',
      sentence: json['sentence'] as String? ?? '',
      scores: ScoreCard.fromJson(
        json['scores'] as Map<String, dynamic>? ?? const {},
      ),
      recommendation: json['recommendation'] as String? ?? '',
    );
  }
}

class Charge {
  Charge({
    required this.title,
    required this.detail,
    required this.severity,
  });

  final String title;
  final String detail;
  final int severity;

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      title: json['title'] as String? ?? 'Suspicious behavior',
      detail: json['detail'] as String? ?? '',
      severity: json['severity'] as int? ?? 5,
    );
  }
}

class ScoreCard {
  ScoreCard({
    required this.chaos,
    required this.taste,
    required this.discipline,
    required this.mainCharacter,
  });

  final int chaos;
  final int taste;
  final int discipline;
  final int mainCharacter;

  factory ScoreCard.fromJson(Map<String, dynamic> json) {
    return ScoreCard(
      chaos: json['chaos'] as int? ?? 0,
      taste: json['taste'] as int? ?? 0,
      discipline: json['discipline'] as int? ?? 0,
      mainCharacter: json['main_character'] as int? ?? 0,
    );
  }
}

class _EncodedImage {
  _EncodedImage({
    required this.base64Data,
    required this.mimeType,
  });

  final String base64Data;
  final String mimeType;
}
