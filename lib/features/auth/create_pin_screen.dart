import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../guest/guest_home_screen.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _pin = '';
  String _repeatPin = '';
  String? _errorText;

  bool get _isEnteringRepeat => _pin.length == 4;
  int get _activeRow => _isEnteringRepeat ? 1 : 0;
  int get _activeIndex => _isEnteringRepeat ? _repeatPin.length : _pin.length;

  void _handleDigit(String digit) {
    setState(() {
      _errorText = null;
      if (!_isEnteringRepeat) {
        _pin += digit;
      } else if (_repeatPin.length < 4) {
        _repeatPin += digit;
      }
    });

    if (_pin.length == 4 && _repeatPin.length == 4) {
      _submitPin();
    }
  }

  void _handleBackspace() {
    setState(() {
      _errorText = null;
      if (_repeatPin.isNotEmpty) {
        _repeatPin = _repeatPin.substring(0, _repeatPin.length - 1);
      } else if (_pin.isNotEmpty && _pin.length < 4) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _submitPin() async {
    if (_pin != _repeatPin) {
      setState(() {
        _errorText = 'ПИН-коды не совпадают';
        _repeatPin = '';
      });
      return;
    }

    // Temporary MVP simulation until real QR verification and secure PIN flow exist.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasExtendedAccess', true);
    await prefs.setString('userPin', _pin);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Расширенный доступ активирован')),
    );
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
                          label: 'Придумайте пин-код',
                          length: _pin.length,
                          activeIndex: _activeRow == 0 ? _activeIndex : null,
                        ),
                        const SizedBox(height: 26),
                        _PinInputRow(
                          label: 'Повторите пин-код',
                          length: _repeatPin.length,
                          activeIndex: _activeRow == 1 ? _activeIndex : null,
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
  final int? activeIndex;

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
