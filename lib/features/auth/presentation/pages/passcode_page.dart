import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/design_system/app_text_styles.dart';
import '../../../../core/localization/localization_service.dart';
import '../../../../core/services/passcode_service.dart';

enum PasscodeMode { setup, enter, disable, change }
enum PasscodeStep { verifyOld, enterNew, confirmNew }

class PasscodePage extends StatefulWidget {
  final PasscodeMode mode;
  final String? userId;
  final void Function(BuildContext context)? onSuccess;

  const PasscodePage({
    super.key,
    required this.mode,
    this.userId,
    this.onSuccess,
  });

  @override
  State<PasscodePage> createState() => _PasscodePageState();
}

class _PasscodePageState extends State<PasscodePage> {
  String _pin = '';
  String _firstPin = ''; // Used during setup / change mode to confirm PIN
  String _errorMessage = '';
  PasscodeStep _step = PasscodeStep.enterNew;
  bool _hasExistingPasscode = false;
  bool _isLoadingInitialState = true;

  final _localAuth = LocalAuthentication();
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _initPasscodeState();
  }

  Future<void> _initPasscodeState() async {
    final box = Hive.isBoxOpen('settings')
        ? Hive.box('settings')
        : await Hive.openBox('settings');
    final savedPin = PasscodeService.getPasscode(uid: widget.userId, box: box);
    final isEnabled =
        PasscodeService.isPasscodeEnabled(uid: widget.userId, box: box);
    _hasExistingPasscode =
        (savedPin != null && savedPin.isNotEmpty && isEnabled);

    if (widget.mode == PasscodeMode.change ||
        (widget.mode == PasscodeMode.setup && _hasExistingPasscode)) {
      _step = PasscodeStep.verifyOld;
    } else {
      _step = PasscodeStep.enterNew;
    }

    if (mounted) {
      setState(() {
        _isLoadingInitialState = false;
      });
      _checkBiometrics();
    }
  }

  void _checkBiometrics() async {
    if (widget.mode == PasscodeMode.enter) {
      final box = Hive.isBoxOpen('settings')
          ? Hive.box('settings')
          : await Hive.openBox('settings');
      final isBiometricEnabled =
          PasscodeService.isBiometricEnabled(uid: widget.userId, box: box);
      if (isBiometricEnabled) {
        final isAvailable = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();
        if (isAvailable && isDeviceSupported && mounted) {
          setState(() {
            _canCheckBiometrics = true;
          });
          _authenticateWithBiometrics();
        }
      }
    }
  }

  void _authenticateWithBiometrics() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: LocalizationService.translate('enter_passcode'),
      );
      if (authenticated && mounted) {
        if (widget.onSuccess != null) {
          widget.onSuccess!(context);
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      // Ignore or log
    }
  }

  void _onNumberTap(int number) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += number.toString();
      _errorMessage = '';
    });

    if (_pin.length == 4) {
      // Small delay before verifying to let the last dot fill
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _verifyPin();
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = '';
    });
  }

  void _verifyPin() async {
    final box = Hive.isBoxOpen('settings')
        ? Hive.box('settings')
        : await Hive.openBox('settings');
    final savedPin = PasscodeService.getPasscode(uid: widget.userId, box: box);

    if (widget.mode == PasscodeMode.enter) {
      if (savedPin == _pin) {
        if (widget.onSuccess != null) {
          widget.onSuccess!(context);
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _pin = '';
          _errorMessage = LocalizationService.translate('wrong_passcode');
        });
      }
      return;
    }

    if (widget.mode == PasscodeMode.disable) {
      if (savedPin == _pin) {
        await PasscodeService.disablePasscode(uid: widget.userId, box: box);
        if (widget.onSuccess != null) {
          widget.onSuccess!(context);
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _pin = '';
          _errorMessage = LocalizationService.translate('wrong_passcode');
        });
      }
      return;
    }

    // Handling setup and change modes
    if (_step == PasscodeStep.verifyOld) {
      if (savedPin == _pin) {
        setState(() {
          _pin = '';
          _step = PasscodeStep.enterNew;
          _errorMessage = '';
        });
      } else {
        setState(() {
          _pin = '';
          _errorMessage = LocalizationService.translate('wrong_passcode');
        });
      }
      return;
    }

    if (_step == PasscodeStep.enterNew) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = PasscodeStep.confirmNew;
        _errorMessage = '';
      });
      return;
    }

    if (_step == PasscodeStep.confirmNew) {
      if (_firstPin == _pin) {
        await PasscodeService.setPasscode(_pin, uid: widget.userId, box: box);
        if (widget.onSuccess != null) {
          widget.onSuccess!(context);
        } else {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _pin = '';
          _firstPin = '';
          _step = PasscodeStep.enterNew;
          _errorMessage = LocalizationService.translate('passcode_mismatch');
        });
      }
    }
  }

  String _getHeaderText() {
    if (widget.mode == PasscodeMode.enter ||
        widget.mode == PasscodeMode.disable) {
      return LocalizationService.translate('enter_passcode');
    }

    if (_step == PasscodeStep.verifyOld) {
      return LocalizationService.translate('enter_current_passcode');
    } else if (_step == PasscodeStep.enterNew) {
      return (_hasExistingPasscode || widget.mode == PasscodeMode.change)
          ? LocalizationService.translate('enter_new_passcode')
          : LocalizationService.translate('create_passcode');
    } else {
      return LocalizationService.translate('confirm_passcode');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingInitialState) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const SizedBox.shrink(),
      );
    }

    return WillPopScope(
      onWillPop: () async => widget.mode != PasscodeMode.enter,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top Spacing & Back Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.mode != PasscodeMode.enter)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: isDark ? Colors.white70 : Colors.black54,
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 48),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 16),
                // Shield Icon & Title
                Icon(
                  Icons.lock_outline_rounded,
                  size: 60,
                  color: AppColors.primary,
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _getHeaderText(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h2().copyWith(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Dots indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppColors.primary
                            : (isDark ? Colors.white24 : Colors.black12),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                // Error Message
                Container(
                  height: 24,
                  alignment: Alignment.center,
                  child: _errorMessage.isNotEmpty
                      ? Text(
                          _errorMessage,
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ).animate().shake(duration: 400.ms)
                      : null,
                ),
                const SizedBox(height: 20),
                // Keypad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildKeypadButton(1),
                          _buildKeypadButton(2),
                          _buildKeypadButton(3),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildKeypadButton(4),
                          _buildKeypadButton(5),
                          _buildKeypadButton(6),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildKeypadButton(7),
                          _buildKeypadButton(8),
                          _buildKeypadButton(9),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _canCheckBiometrics
                              ? Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.05)
                                        : Colors.black.withOpacity(0.05),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.fingerprint_rounded),
                                    color: AppColors.primary,
                                    onPressed: _authenticateWithBiometrics,
                                  ),
                                )
                              : (widget.mode != PasscodeMode.enter
                                  ? SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text(
                                          LocalizationService.translate('cancel'),
                                          style: const TextStyle(
                                              color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                    )
                                  : const SizedBox(width: 64, height: 64)),
                          _buildKeypadButton(0),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.black.withOpacity(0.05),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.backspace_outlined),
                              color: isDark ? Colors.white70 : Colors.black54,
                              onPressed: _onBackspace,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(int value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _onNumberTap(value),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
