import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/session_service.dart';
import '../guest/guest_home_screen.dart';
import 'create_pin_screen.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  String _pin = '';
  String? _errorText;

  void _handleDigit(String digit) {
    if (_pin.length == 4) {
      return;
    }

    setState(() {
      _errorText = null;
      _pin += digit;
    });

    if (_pin.length == 4) {
      _submitPin();
    }
  }

  void _handleBackspace() {
    if (_pin.isEmpty) {
      return;
    }

    setState(() {
      _errorText = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submitPin() async {
    final sessionService = SessionService();
    final isValidPin = await sessionService.verifyPin(_pin);

    if (!isValidPin) {
      setState(() {
        _errorText = 'Неверный ПИН-код';
        _pin = '';
      });
      return;
    }

    if (_pin != SessionService.demoPin) {
      await sessionService.updatePin(_pin);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Вход выполнен')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (context) => const GuestHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.greyStatus,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/create_pin_bg.png', fit: BoxFit.cover),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
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
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, 0.56),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _PinInputRow(
                          label: 'Введите пин-код',
                          length: _pin.length,
                          activeIndex: _pin.length,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: _PinInputRow.rowWidth,
                          height: 22,
                          child: Text(
                            _errorText ?? '',
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.pinkAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: _PinInputRow.rowWidth,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (context) => const CreatePinScreen(
                                      isPasswordReset: true,
                                    ),
                                  ),
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Забыли пароль?',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFFD9D9D9),
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color(
                                          0xFFD9D9D9,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _NumericKeypad(
                  onDigit: _handleDigit,
                  onBackspace: _handleBackspace,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinInputRow extends StatelessWidget {
  const _PinInputRow({
    required this.label,
    required this.length,
    required this.activeIndex,
  });

  final String label;
  final int length;
  final int activeIndex;

  static const double cellWidth = 47;
  static const double gap = 17;
  static const double rowWidth = cellWidth * 4 + gap * 3;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: rowWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFD9D9D9),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < 4; index++) ...[
                  _PinCell(
                    isFilled: index < length,
                    isActive: activeIndex == index,
                  ),
                  if (index < 3) const SizedBox(width: gap),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({required this.isFilled, required this.isActive});

  final bool isFilled;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: 47,
        height: 56,
        child: Center(
          child: _PinCellContent(isFilled: isFilled, isActive: isActive),
        ),
      ),
    );
  }
}

class _PinCellContent extends StatelessWidget {
  const _PinCellContent({required this.isFilled, required this.isActive});

  final bool isFilled;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.yellowAccent.withValues(alpha: 0.72),
          shape: BoxShape.circle,
        ),
        child: const SizedBox.square(dimension: 16),
      );
    }

    if (isActive) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF222423),
          borderRadius: BorderRadius.circular(2),
        ),
        child: const SizedBox(width: 1.5, height: 26),
      );
    }

    return const SizedBox.shrink();
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFD1D4D8),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 4, 5, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _KeypadRow(values: const ['1', '2', '3'], onDigit: onDigit),
              const SizedBox(height: 6),
              _KeypadRow(values: const ['4', '5', '6'], onDigit: onDigit),
              const SizedBox(height: 6),
              _KeypadRow(values: const ['7', '8', '9'], onDigit: onDigit),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(child: SizedBox(height: 48)),
                  Expanded(
                    child: _KeyButton(label: '0', onTap: () => onDigit('0')),
                  ),
                  Expanded(
                    child: IconButton(
                      onPressed: onBackspace,
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.values, required this.onDigit});

  final List<String> values;
  final ValueChanged<String> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _KeyButton(label: value, onTap: () => onDigit(value)),
            ),
          ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
