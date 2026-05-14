import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../events/events_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/state_notes_screen.dart';

class StateNoteDetailScreen extends StatefulWidget {
  const StateNoteDetailScreen({super.key, required this.stateNoteId});

  final String stateNoteId;

  @override
  State<StateNoteDetailScreen> createState() => _StateNoteDetailScreenState();
}

class _StateNoteDetailScreenState extends State<StateNoteDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorText;
  StateNoteItem? _note;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final data = await _supabase
          .from('state_notes')
          .select(
            'state_note_id, title, note_created_at, anxiety_level, mood_level, social_comfort_level, comment',
          )
          .eq('state_note_id', widget.stateNoteId)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      if (data.isEmpty) {
        setState(() {
          _errorText = 'Заметка не найдена.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _note = StateNoteItem.fromJson(Map<String, dynamic>.from(data.first));
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('State note detail load error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Не удалось загрузить заметку.';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote() async {
    if (_isDeleting || _note == null) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await _supabase
          .from('state_notes')
          .delete()
          .eq('state_note_id', widget.stateNoteId)
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('State note delete error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить заметку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;

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
            child: RefreshIndicator(
              onRefresh: _loadNote,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 188),
                children: [
                  const _BackButtonText(),
                  const SizedBox(height: 26),
                  Text(
                    note?.title ?? 'Заметка о состоянии',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note == null ? '' : formatDate(note.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildContent(context),
                ],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: MediaQuery.paddingOf(context).bottom + 103,
            child: FilledButton(
              onPressed: _isDeleting || _isLoading || _errorText != null
                  ? null
                  : _deleteNote,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD9D9D9),
                foregroundColor: AppColors.textDark,
                disabledBackgroundColor: const Color(
                  0xFFD9D9D9,
                ).withValues(alpha: 0.58),
                disabledForegroundColor: AppColors.textDark.withValues(
                  alpha: 0.56,
                ),
                minimumSize: const Size.fromHeight(58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(29),
                ),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(_isDeleting ? 'Удаление...' : 'Удалить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorText != null) {
      return _MessageText(text: _errorText!);
    }

    final note = _note;
    if (note == null) {
      return const _MessageText(text: 'Заметка не найдена.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SoftCard(
          child: Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  icon: Icons.bolt_outlined,
                  label: 'Тревожность',
                  value: note.anxietyLevel,
                  color: AppColors.pinkAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBlock(
                  icon: Icons.show_chart,
                  label: 'Настроение',
                  value: note.moodLevel,
                  color: AppColors.yellowAccent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBlock(
                  icon: Icons.groups_2_outlined,
                  label: 'Комфорт в общении',
                  value: note.socialComfortLevel,
                  color: AppColors.blueAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Комментарий',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                note.comment.isEmpty ? 'Комментарий не добавлен' : note.comment,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Color.lerp(color, AppColors.textDark, 0.55)!;

    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SizedBox.square(
              dimension: 23,
              child: Icon(icon, size: 14, color: foregroundColor),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF777777),
                    height: 1.08,
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value/10',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1,
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

class _SoftCard extends StatelessWidget {
  const _SoftCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _BackButtonText extends StatelessWidget {
  const _BackButtonText();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '← Назад',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF777777),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopGlow extends StatelessWidget {
  const _TopGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.yellowAccent.withValues(alpha: 0.78),
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

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF777777)),
      ),
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
