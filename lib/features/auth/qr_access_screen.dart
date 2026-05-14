import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'create_pin_screen.dart';

class QRAccessScreen extends StatefulWidget {
  const QRAccessScreen({super.key});

  @override
  State<QRAccessScreen> createState() => _QRAccessScreenState();
}

class _QRAccessScreenState extends State<QRAccessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRegistrationNotice();
    });
  }

  Future<void> _showRegistrationNotice() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.22),
      builder: (context) {
        return const _RegistrationNoticeDialog();
      },
    );
  }

  void _simulateQrSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const CreatePinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.greyStatus,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 10,
              top: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '← Назад',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(18),
                        child: SizedBox.square(
                          dimension: 300,
                          child: CustomPaint(painter: _FakeQrPainter()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 23),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _simulateQrSuccess,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE1E1E1),
                          foregroundColor: AppColors.textDark,
                          minimumSize: const Size.fromHeight(62),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(31),
                          ),
                        ),
                        child: const Text('Перевернуть камеру'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationNoticeDialog extends StatelessWidget {
  const _RegistrationNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final dialogWidth = MediaQuery.sizeOf(context).width * 0.9;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: dialogWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Чтобы открыть расширенный функционал,\n'
                    'вам необходимо наблюдаться в одном из\n'
                    'центров ментального здоровья (ЦМЗ).',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Сайт ЦМЗ будет открыт позже'),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.yellowAccent,
                      foregroundColor: AppColors.textDark,
                      minimumSize: const Size.fromHeight(62),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(31),
                      ),
                    ),
                    child: const Text('Открыть сайт ЦМЗ'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9D9D9),
                    foregroundColor: AppColors.textDark,
                    minimumSize: const Size.fromHeight(62),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(31),
                    ),
                  ),
                  child: const Text('Понятно'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeQrPainter extends CustomPainter {
  const _FakeQrPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final cell = size.width / 29;

    void drawFinder(int x, int y) {
      canvas.drawRect(
        Rect.fromLTWH(x * cell, y * cell, 7 * cell, 7 * cell),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH((x + 1) * cell, (y + 1) * cell, 5 * cell, 5 * cell),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH((x + 2) * cell, (y + 2) * cell, 3 * cell, 3 * cell),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(22, 0);
    drawFinder(0, 22);

    for (var y = 0; y < 29; y++) {
      for (var x = 0; x < 29; x++) {
        final inFinder =
            (x < 8 && y < 8) || (x > 20 && y < 8) || (x < 8 && y > 20);
        if (inFinder) {
          continue;
        }

        final shouldDraw = (x * 7 + y * 11 + x * y) % 5 < 2;
        if (shouldDraw) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
