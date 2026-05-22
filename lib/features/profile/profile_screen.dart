import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import 'doctor_recommendations_screen.dart';
import 'state_notes_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  String _fullName = 'Елизавета';
  int _readArticlesCount = 5;
  int _completedMeetingsCount = 3;
  Uint8List? _avatarBytes;
  bool _isPickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getString(_avatarPrefsKey);
      debugPrint(
        'Loaded profile avatar base64 length: ${savedValue?.length ?? 0}',
      );
      if (savedValue == null || savedValue.isEmpty) {
        if (!mounted) {
          return;
        }
        setState(() {
          _avatarBytes = null;
        });
        return;
      }

      try {
        final decodedBytes = base64Decode(savedValue);
        debugPrint('Decoded avatar bytes length: ${decodedBytes.length}');
        if (decodedBytes.isEmpty) {
          throw StateError('Decoded avatar bytes are empty');
        }

        if (!mounted) {
          return;
        }
        setState(() {
          _avatarBytes = decodedBytes;
        });
      } catch (error, stackTrace) {
        debugPrint('Profile avatar decode error: $error');
        debugPrintStack(stackTrace: stackTrace);
        await prefs.remove(_avatarPrefsKey);
        if (!mounted) {
          return;
        }
        setState(() {
          _avatarBytes = null;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Profile avatar load error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _pickAvatarImage() async {
    if (_isPickingAvatar) {
      return;
    }

    debugPrint('Profile avatar tap happened');

    if (mounted) {
      setState(() {
        _isPickingAvatar = true;
      });
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (pickedFile == null) {
        debugPrint('Profile avatar picker returned null');
        return;
      }

      debugPrint('Profile avatar picker returned file: ${pickedFile.path}');
      final bytes = await pickedFile.readAsBytes();
      debugPrint('Picked avatar bytes length: ${bytes.length}');
      if (bytes.isEmpty) {
        throw StateError('Picked avatar bytes are empty');
      }

      final prefs = await SharedPreferences.getInstance();
      final encoded = base64Encode(bytes);
      await prefs.setString(_avatarPrefsKey, encoded);
      debugPrint('Avatar picked and saved. Bytes: ${bytes.length}');

      if (!mounted) {
        return;
      }
      setState(() {
        _avatarBytes = bytes;
      });
    } catch (error, stackTrace) {
      debugPrint('Profile avatar pick error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось выбрать фото')));
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAvatar = false;
        });
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final patientExternalId = await SessionService()
          .getCurrentPatientExternalId();
      debugPrint('Profile patient external id: $patientExternalId');

      final patient = await _loadPatient(patientExternalId);
      debugPrint(
        'Loaded profile patient: patient_id=${patient.id}, full_name=${patient.fullName}',
      );

      final results = await Future.wait([
        _loadCompletedMaterialsCount(patient.id),
        _loadAcceptedEventsCount(patient.id),
      ]).timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      setState(() {
        _fullName = patient.fullName;
        _readArticlesCount = results[0];
        _completedMeetingsCount = results[1];
      });
    } catch (error, stackTrace) {
      debugPrint('Profile stats load error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<_ProfilePatient> _loadPatient(String patientExternalId) async {
    try {
      final data = await _supabase
          .from('patients')
          .select('patient_id, full_name')
          .eq('external_patient_id', patientExternalId)
          .limit(1);

      debugPrint('Loaded profile patient raw response: $data');

      if (data.isEmpty) {
        debugPrint(
          'Profile patient query returned no rows for external id: $patientExternalId',
        );
        throw StateError('Profile patient not found');
      }

      final row = Map<String, dynamic>.from(data.first);
      final patientId = row['patient_id'];
      final fullName = row['full_name']?.toString().trim();

      if (patientId == null || fullName == null || fullName.isEmpty) {
        debugPrint('Profile patient row is incomplete: $row');
        throw StateError('Profile patient row is incomplete');
      }

      return _ProfilePatient(id: patientId, fullName: fullName);
    } catch (error, stackTrace) {
      debugPrint('Profile patient load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<int> _loadCompletedMaterialsCount(Object patientId) async {
    final data = await _supabase
        .from('material_views')
        .select('patient_id')
        .eq('patient_id', patientId)
        .eq('reading_status', 'completed');

    final count = data.length;
    debugPrint('Completed materials count for patient_id=$patientId: $count');
    return count;
  }

  Future<int> _loadAcceptedEventsCount(Object patientId) async {
    final data = await _supabase
        .from('event_requests')
        .select('patient_id')
        .eq('patient_id', patientId)
        .eq('request_status', 'accepted');

    final count = data.length;
    debugPrint('Accepted events count for patient_id=$patientId: $count');
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 3,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: Stack(
        children: [
          const _TopGlow(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 39, 22, 126),
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.settings_outlined,
                    size: 25,
                    color: Color(0xFF767676),
                  ),
                ),
                const SizedBox(height: 5),
                _Avatar(
                  avatarBytes: _avatarBytes,
                  isPickingAvatar: _isPickingAvatar,
                  onTap: _pickAvatarImage,
                ),
                const SizedBox(height: 16),
                Text(
                  _fullName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 39),
                _StatisticsCard(
                  readArticlesCount: _readArticlesCount,
                  completedMeetingsCount: _completedMeetingsCount,
                ),
                const SizedBox(height: 26),
                const _ProfileMenuCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePatient {
  const _ProfilePatient({required this.id, required this.fullName});

  final Object id;
  final String fullName;
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 236,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.yellowAccent.withValues(alpha: 0.74),
                AppColors.yellowAccent.withValues(alpha: 0.28),
                AppColors.background.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _avatarPrefsKey = 'profile_avatar_base64';

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.avatarBytes,
    required this.isPickingAvatar,
    required this.onTap,
  });

  final Uint8List? avatarBytes;
  final bool isPickingAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.blueAccent.withValues(alpha: 0.75),
                    AppColors.pinkAccent.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _AvatarContent(avatarBytes: avatarBytes, size: 128),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                child: SizedBox.square(
                  dimension: 34,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.photo_camera_outlined,
                        size: 18,
                        color: Color(0xFF191919),
                      ),
                      if (isPickingAvatar)
                        const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF191919),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarContent extends StatelessWidget {
  const _AvatarContent({required this.avatarBytes, required this.size});

  final Uint8List? avatarBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = avatarBytes;
    if (bytes == null || bytes.isEmpty) {
      return _AvatarPlaceholder(size: size);
    }

    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEED9D9),
      ),
      child: const Icon(Icons.person_outline, color: Color(0xFF191919)),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.readArticlesCount,
    required this.completedMeetingsCount,
  });

  final int readArticlesCount;
  final int completedMeetingsCount;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Персональная статистика',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Text(
                'Последние 30 дней',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF777777),
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.keyboard_arrow_down, size: 17),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 13),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _StatColumn(
                      icon: Icons.article_outlined,
                      label: 'прочитанные статьи',
                      value: readArticlesCount,
                    ),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFBDBDBD),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _StatColumn(
                      icon: Icons.people_alt_outlined,
                      label: 'завершённые встречи',
                      value: completedMeetingsCount,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: AppColors.textDark),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontSize: 12.5, height: 1.15),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard();

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.medical_services_outlined,
            label: 'Рекомендации врача',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const DoctorRecommendationsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 20, color: Color(0xFFD0D0D0)),
          _MenuRow(
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: 'Мои заметки о состоянии',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const StateNotesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF777777)),
          ],
        ),
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  const _SoftCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

void _handleExtendedNavigation(BuildContext context, int index) {
  if (index == 0) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const GuestHomeScreen()),
      (route) => false,
    );
    return;
  }

  if (index == 1) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const EventsScreen()),
    );
    return;
  }

  if (index == 2) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const ActivityCalendarScreen(),
      ),
    );
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
  );
}
