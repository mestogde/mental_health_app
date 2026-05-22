import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/guest_bottom_navigation.dart';
import '../../data/services/session_service.dart';
import '../calendar/activity_calendar_screen.dart';
import '../guest/guest_home_screen.dart';
import '../profile/profile_screen.dart';
import 'event_detail_models.dart';

class EventForeignDetailScreen extends StatefulWidget {
  const EventForeignDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventForeignDetailScreen> createState() =>
      _EventForeignDetailScreenState();
}

class _EventForeignDetailScreenState extends State<EventForeignDetailScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorText;
  Object? _currentPatientId;
  EventDetailItem? _event;
  EventPatientProfile? _organizer;
  EventRequestDetail? _request;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final patientId = await _loadCurrentPatientId();
      final eventData = await _supabase
          .from('events')
          .select('*')
          .eq('event_id', widget.eventId)
          .limit(1)
          .timeout(const Duration(seconds: 10));

      if (eventData.isEmpty) {
        throw StateError('Event not found: ${widget.eventId}');
      }

      final event = EventDetailItem.fromJson(
        Map<String, dynamic>.from(eventData.first),
      );
      final organizer = await _loadPatientProfile(event.creatorPatientId);
      final request = await _loadCurrentRequest(patientId);

      if (!mounted) {
        return;
      }
      setState(() {
        _currentPatientId = patientId;
        _event = event;
        _organizer = organizer;
        _request = request;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Foreign event detail load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'Не удалось загрузить событие';
        _isLoading = false;
      });
    }
  }

  Future<Object> _loadCurrentPatientId() async {
    final externalId = await SessionService().getCurrentPatientExternalId();
    final data = await _supabase
        .from('patients')
        .select('patient_id')
        .eq('external_patient_id', externalId)
        .limit(1)
        .timeout(const Duration(seconds: 10));

    if (data.isEmpty || data.first['patient_id'] == null) {
      throw StateError('Patient not found for external id: $externalId');
    }
    return data.first['patient_id'];
  }

  Future<EventPatientProfile?> _loadPatientProfile(Object? patientId) async {
    if (patientId == null) {
      return null;
    }
    try {
      final data = await _supabase
          .from('patients')
          .select('*')
          .eq('patient_id', patientId)
          .limit(1)
          .timeout(const Duration(seconds: 10));
      if (data.isEmpty) {
        return null;
      }
      return EventPatientProfile.fromJson(
        Map<String, dynamic>.from(data.first),
      );
    } catch (error, stackTrace) {
      debugPrint('Foreign event organizer load error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<EventRequestDetail?> _loadCurrentRequest(Object patientId) async {
    final data = await _supabase
        .from('event_requests')
        .select('*')
        .eq('event_id', widget.eventId)
        .eq('patient_id', patientId)
        .limit(1)
        .timeout(const Duration(seconds: 10));
    if (data.isEmpty) {
      return null;
    }
    return EventRequestDetail.fromJson(Map<String, dynamic>.from(data.first));
  }

  Future<void> _submitRequest() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напишите сообщение организатору')),
      );
      return;
    }

    final patientId = _currentPatientId;
    if (patientId == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _supabase
          .from('event_requests')
          .insert({
            'event_id': widget.eventId,
            'patient_id': patientId,
            'request_text': message,
            'request_status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Запрос отправлен')));
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Event request insert error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить запрос')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      bottomNavigationBar: GuestBottomNavigation(
        selectedIndex: 1,
        onItemTap: (index) => _handleExtendedNavigation(context, index),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDetails,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 132),
            children: [
              const _BackButtonText(),
              const SizedBox(height: 26),
              Text(
                'Событие',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              _buildContent(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 360,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorText != null) {
      return _MessageText(text: _errorText!);
    }
    final event = _event;
    if (event == null) {
      return const _MessageText(text: 'Событие не найдено');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EventDetailCard(event: event, request: _request),
        const SizedBox(height: 14),
        _InfoCard(
          rows: [
            _InfoRow(label: 'Формат', value: event.normalizedFormat),
            _InfoRow(
              label: 'Организатор',
              value: _organizer?.displayNameWithAge ?? 'Не указан',
            ),
          ],
        ),
        const SizedBox(height: 22),
        _buildRequestSection(context),
      ],
    );
  }

  Widget _buildRequestSection(BuildContext context) {
    final request = _request;
    if (request?.isAccepted ?? false) {
      return const SizedBox(
        width: double.infinity,
        child: _InfoText(text: 'Вы уже участвуете в этом событии'),
      );
    }
    if (request?.isPending ?? false) {
      return const SizedBox(
        width: double.infinity,
        child: _InfoText(text: 'Запрос уже отправлен и ожидает подтверждения'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сообщение организатору',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _messageController,
          minLines: 4,
          maxLines: 5,
          decoration: InputDecoration(
            hintText:
                'Напишите пару слов о себе и почему хотите присоединиться к событию',
            hintStyle: const TextStyle(color: Color(0xFFA7A7A7), fontSize: 13),
            filled: true,
            fillColor: AppColors.surface.withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.pinkAccent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitRequest,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pinkAccent,
            foregroundColor: AppColors.textDark,
            minimumSize: const Size.fromHeight(58),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(29),
            ),
            textStyle: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          child: Text(_isSubmitting ? 'Отправка...' : 'Отправить запрос'),
        ),
      ],
    );
  }
}

class _EventDetailCard extends StatelessWidget {
  const _EventDetailCard({required this.event, required this.request});
  final EventDetailItem event;
  final EventRequestDetail? request;

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryIcon(category: event.category),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (request != null) ...[
                const SizedBox(width: 8),
                _StatusChip(
                  text: request!.isAccepted
                      ? 'Вы участвуете'
                      : requestStatusText(request!),
                  color: requestStatusColor(request!),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _DetailMeta(icon: Icons.place_outlined, text: event.location),
          const SizedBox(height: 8),
          _DetailMeta(
            icon: Icons.schedule,
            text: formatEventDateTime(event.startsAt),
          ),
          const SizedBox(height: 8),
          _DetailMeta(
            icon: Icons.people_alt_outlined,
            text: participantText(event.participantLimit),
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              event.description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF777777)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});
  final List<_InfoRow> rows;
  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index],
            if (index < rows.length - 1)
              const Divider(height: 20, color: Color(0xFFCFCFCF)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(color: Color(0xFF777777))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
        ),
      ],
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
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});
  final String category;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pinkAccent.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(
          eventCategoryIcon(category),
          size: 23,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _DetailMeta extends StatelessWidget {
  const _DetailMeta({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF777777)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF777777)),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.textDark,
            fontSize: 10,
            height: 1,
          ),
        ),
      ),
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

class _MessageText extends StatelessWidget {
  const _MessageText({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Center(
        child: Text(text, style: const TextStyle(color: Color(0xFF777777))),
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
