import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:yugo/extensions/context_extensions.dart';
import 'package:yugo/screens/permissions_screen.dart';
import 'package:yugo/screens/pin_verify_screen.dart';
import 'package:yugo/screens/block_edit_screen.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';
import 'package:yugo/screens/app_picker_screen.dart';
import 'package:yugo/utils/app_utils.dart';

class AppListScreen extends StatefulWidget {
  const AppListScreen({super.key, this.initialBlocks});

  final List<Map<String, dynamic>>? initialBlocks;

  @override
  State<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends State<AppListScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _blocks = [];
  bool _loading = true;
  bool _permissionsOk = false;
  bool? _lastPermissionsOk;
  bool _adminEnabled = false;
  int _adminLockUntilMs = 0;
  bool _adminLockExpiryNotified = false;
  bool _accessVerified = false;
  Timer? _refreshTimer;
  Timer? _adminLockTimer;
  final Set<String> _scheduleDirty = {};
  final Set<String> _dateBlockDirty = {};
  final Set<String> _iconLoading = {};
  final Map<String, Uint8List> _iconCache = {};
  final int _iconPrefetchCount = 12;
  final String _sortMode = 'smart';
  String _expiredAction = 'none';
  bool _expiredPrefsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialBlocks != null) {
      _blocks = widget.initialBlocks!;
      _loading = false;
    }
    _init();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _adminLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ensureAppAccess();
      _checkPermissions();
      _loadAdminLockPrefs();
      if (widget.initialBlocks == null) {
        _loadBlocks();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_adminEnabled && mounted) {
        setState(() => _accessVerified = false);
      } else {
        _accessVerified = false;
      }
    }
  }

  Future<void> _init() async {
    await _startMonitoring();
    await _checkPermissions();
    await _ensureAppAccess();
    await _loadExpiredPrefs();
    await _loadAdminLockPrefs();
    if (widget.initialBlocks == null) {
      await _loadBlocks();
    }
    _startAutoRefresh();
  }

  Future<void> _ensureAppAccess() async {
    if (_accessVerified || !mounted) return;
    final navigator = Navigator.of(context);
    final enabled = await NativeService.isAdminEnabled();
    if (!mounted) return;
    if (!enabled) {
      _accessVerified = true;
      return;
    }
    bool verified = false;
    while (mounted && !verified) {
      final result = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => const PinVerifyScreen(
            reason: 'Ingresa tu PIN para acceder a Yugo',
          ),
        ),
      );
      verified = result == true;
      if (!verified) {
        final stillEnabled = await NativeService.isAdminEnabled();
        if (!mounted || !stillEnabled) {
          verified = true;
        }
      }
    }
    if (mounted) {
      setState(() => _accessVerified = true);
    } else {
      _accessVerified = true;
    }
  }

  Future<void> _loadAdminLockPrefs() async {
    try {
      final prefs =
          await NativeService.getSharedPreferences('admin_lock_prefs');
      final until = (prefs?['lock_until_ms'] as num?)?.toInt() ?? 0;
      final lockActive = until > DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() {
        _adminLockUntilMs = until;
        if (lockActive) {
          _adminLockExpiryNotified = false;
        }
      });
      _startAdminLockCountdown();
      await _clearAdminLockIfExpired();
    } catch (_) {}
  }

  bool get _adminLockActive =>
      _adminLockUntilMs > DateTime.now().millisecondsSinceEpoch;

  int get _adminLockRemainingMs {
    final remaining = _adminLockUntilMs - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : 0;
  }

  Future<void> _clearAdminLockIfExpired() async {
    if (_adminLockUntilMs <= 0) return;
    if (_adminLockActive) return;
    _adminLockTimer?.cancel();
    _adminLockUntilMs = 0;
    await NativeService.saveSharedPreference({
      'prefsName': 'admin_lock_prefs',
      'key': 'lock_until_ms',
      'value': null,
    });
    if (!mounted) return;
    setState(() {});
    if (!_adminLockExpiryNotified) {
      _adminLockExpiryNotified = true;
      context.showSnack('El modo admin temporal venció. Ya puedes hacer cambios.');
    }
  }

  void _startAdminLockCountdown() {
    _adminLockTimer?.cancel();
    if (!_adminLockActive) return;
    _adminLockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_adminLockActive) {
        _adminLockTimer?.cancel();
        _clearAdminLockIfExpired();
      } else {
        setState(() {});
      }
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || _loading) return;
      _checkPermissions();
      _loadBlocks();
    });
  }

  void _notifyPermissionChange(bool nowOk) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          nowOk
              ? 'Permisos críticos habilitados'
              : 'Faltan permisos críticos para funcionar',
        ),
        action: nowOk
            ? null
            : SnackBarAction(
                label: 'Configurar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionsScreen()),
                ).then((_) => _checkPermissions()),
              ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _checkPermissions() async {
    try {
      final usage = await NativeService.checkUsagePermission();
      final acc = await NativeService.checkAccessibilityPermission();
      final admin = await NativeService.isAdminEnabled();
      final nowOk = usage && acc;
      if (mounted) {
        final prevOk = _lastPermissionsOk;
        setState(() {
          _permissionsOk = nowOk;
          _adminEnabled = admin;
          if (!admin) {
            _accessVerified = true;
          }
          _lastPermissionsOk = nowOk;
        });
        if (prevOk != null && prevOk != nowOk) {
          _notifyPermissionChange(nowOk);
        }
      }
      return nowOk;
    } catch (_) {}
    return _permissionsOk;
  }

  Future<void> _startMonitoring() async {
    try {
      await NativeService.startMonitoring();
    } catch (_) {}
  }

  void _refreshWidgetsSoon() {
    unawaited(NativeService.refreshWidgetsNow());
  }

  void _reloadBlocksSoon() {
    unawaited(_loadBlocks());
  }

  Future<void> _loadExpiredPrefs() async {
    if (_expiredPrefsLoaded) return;
    try {
      final prefs =
          await NativeService.getSharedPreferences('block_prefs');
      final action = prefs?['expired_action']?.toString();
      if (action != null &&
          (action == 'none' || action == 'archive' || action == 'delete')) {
        _expiredAction = action;
      }
    } catch (_) {}
    _expiredPrefsLoaded = true;
  }

  bool _isExpired(Map<String, dynamic> r) {
    final raw = r['expiresAt'];
    if (raw == null) return false;
    final expiresAt =
        raw is num ? raw.toInt() : int.tryParse(raw.toString()) ?? 0;
    if (expiresAt <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }

  Future<void> _loadBlocks() async {
    try {
      await _loadExpiredPrefs();
      final list = await NativeService.getBlocks();
      final existingByPkg = {
        for (final r in _blocks) r['packageName'] as String: r
      };
      final prefetchCount = _iconPrefetchCount == 0 ? 12 : _iconPrefetchCount;
      final prefetchSet = list
          .take(prefetchCount.clamp(0, list.length))
          .map((r) => r['packageName'] as String)
          .toSet();
      var changed = false;

      final filtered = <Map<String, dynamic>>[];
      final toDelete = <String>[];
      for (final r in list) {
        final pkg = r['packageName'] as String;
        final expired = _isExpired(r);
        r['isExpired'] = expired;
        if (expired && _expiredAction == 'delete') {
          toDelete.add(pkg);
          continue;
        }
        if (expired &&
            _expiredAction == 'archive' &&
            (r['isEnabled'] as bool? ?? true)) {
          try {
            await NativeService.updateBlock({
              'packageName': pkg,
              'isEnabled': false,
            });
            r['isEnabled'] = false;
            changed = true;
          } catch (_) {}
        }
        final existing = existingByPkg[pkg];

        // Preserve cached fields to avoid rebuild flicker.
        if (existing != null) {
          r['iconBytes'] = existing['iconBytes'];
          r['scheduleCount'] = existing['scheduleCount'];
          r['scheduleActiveCount'] = existing['scheduleActiveCount'];
          r['dateBlockCount'] = existing['dateBlockCount'];
          r['dateBlockActiveCount'] = existing['dateBlockActiveCount'];
          r['usedMinutes'] = existing['usedMinutes'];
          r['isBlocked'] = existing['isBlocked'];
          r['usedMillis'] = existing['usedMillis'];
          r['usedMinutesWeek'] = existing['usedMinutesWeek'];
          r['isExpired'] = expired;
        }

        final cachedIcon = _iconCache[pkg];
        if (cachedIcon != null && cachedIcon.isNotEmpty) {
          r['iconBytes'] = cachedIcon;
        }

        try {
          final usage = await NativeService.getUsageToday(pkg);
          final usedMinutes = usage['usedMinutes'] ?? 0;
          final isBlocked = usage['isBlocked'] ?? false;
          final usedMillis = usage['usedMillis'] ?? (usedMinutes * 60000);
          final usedMinutesWeek = usage['usedMinutesWeek'] ?? 0;

          if (r['usedMinutes'] != usedMinutes ||
              r['isBlocked'] != isBlocked ||
              r['usedMillis'] != usedMillis ||
              r['usedMinutesWeek'] != usedMinutesWeek) {
            changed = true;
          }

          r['usedMinutes'] = usedMinutes;
          r['isBlocked'] = isBlocked;
          r['usedMillis'] = usedMillis;
          r['usedMinutesWeek'] = usedMinutesWeek;
        } catch (_) {
          // Keep previous values on error to avoid flicker.
        }

        if (r['scheduleCount'] == null || _scheduleDirty.contains(pkg)) {
          try {
            final prevCount = (r['scheduleCount'] as int?) ?? 0;
            final prevActive = (r['scheduleActiveCount'] as int?) ?? 0;
            final schedules = await NativeService.getSchedules(pkg);
            final active = schedules
                .where((s) => (s['isEnabled'] as bool? ?? true))
                .length;
            r['scheduleCount'] = schedules.length;
            r['scheduleActiveCount'] = active;
            if (prevCount != schedules.length || prevActive != active) {
              changed = true;
            }
            _scheduleDirty.remove(pkg);
          } catch (_) {
            r['scheduleCount'] = 0;
            r['scheduleActiveCount'] = 0;
          }
        }

        if (r['dateBlockCount'] == null || _dateBlockDirty.contains(pkg)) {
          try {
            final prevCount = (r['dateBlockCount'] as int?) ?? 0;
            final prevActive = (r['dateBlockActiveCount'] as int?) ?? 0;
            final blocks = await NativeService.getDateBlocks(pkg);
            final active =
                blocks.where((b) => (b['isEnabled'] as bool? ?? true)).length;
            r['dateBlockCount'] = blocks.length;
            r['dateBlockActiveCount'] = active;
            if (prevCount != blocks.length || prevActive != active) {
              changed = true;
            }
            _dateBlockDirty.remove(pkg);
          } catch (_) {
            r['dateBlockCount'] = 0;
            r['dateBlockActiveCount'] = 0;
          }
        }

        if (r['iconBytes'] == null && prefetchSet.contains(pkg)) {
          try {
            final bytes = await NativeService.getAppIcon(pkg);
            if (bytes != null && bytes.isNotEmpty) {
              _iconCache[pkg] = bytes;
              r['iconBytes'] = bytes;
              changed = true;
            }
          } catch (_) {}
        }

        if (existing != null && _sameCardData(existing, r)) {
          filtered.add(existing);
        } else {
          filtered.add(r);
        }
      }

      _sortBlocks(filtered);

      for (final pkg in toDelete) {
        try {
          await NativeService.deleteBlock(pkg);
          changed = true;
        } catch (_) {}
      }

      if (mounted) {
        if (changed || _loading || _blocks.length != filtered.length) {
          setState(() {
            _blocks = filtered;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBlock(String pkg, String name, int minutes,
      {Map<String, dynamic>? limit}) async {
    try {
      await NativeService.addBlock({
        'packageName': pkg,
        'appName': name,
        'dailyQuotaMinutes': minutes,
        'isEnabled': limit?['isEnabled'] ?? true,
        'macroType': 'LIMIT',
        'limitType': limit?['limitType'] ?? 'daily',
        'dailyMode': limit?['dailyMode'] ?? 'same',
        'dailyQuotas': limit?['dailyQuotas'] ?? {},
        'weeklyQuotaMinutes': limit?['weeklyQuotaMinutes'] ?? 0,
        'weeklyResetDay': limit?['weeklyResetDay'] ?? 2,
        'weeklyResetHour': limit?['weeklyResetHour'] ?? 0,
        'weeklyResetMinute': limit?['weeklyResetMinute'] ?? 0,
        'expiresAt': limit?['expiresAt'],
      });
      final optimistic = <String, dynamic>{
        'packageName': pkg,
        'appName': name,
        'dailyQuotaMinutes': minutes,
        'isEnabled': limit?['isEnabled'] ?? true,
        'limitType': limit?['limitType'] ?? 'daily',
        'dailyMode': limit?['dailyMode'] ?? 'same',
        'dailyQuotas': limit?['dailyQuotas'] ?? {},
        'weeklyQuotaMinutes': limit?['weeklyQuotaMinutes'] ?? 0,
        'weeklyResetDay': limit?['weeklyResetDay'] ?? 2,
        'weeklyResetHour': limit?['weeklyResetHour'] ?? 0,
        'weeklyResetMinute': limit?['weeklyResetMinute'] ?? 0,
        'expiresAt': limit?['expiresAt'],
        'usedMinutes': 0,
        'isBlocked': false,
        'usedMillis': 0,
        'usedMinutesWeek': 0,
        'scheduleCount': 0,
        'scheduleActiveCount': 0,
        'dateBlockCount': 0,
        'dateBlockActiveCount': 0,
      };
      if (mounted) {
        setState(() {
          _blocks.removeWhere((x) => x['packageName'] == pkg);
          _blocks.add(optimistic);
          _sortBlocks(_blocks);
        });
      }
      _refreshWidgetsSoon();
      _reloadBlocksSoon();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<bool> _requireAdmin(String reason) async {
    await _loadAdminLockPrefs();
    if (_adminLockActive) {
      if (mounted) {
        context.showSnack(
          'Modo admin temporal activo · '
          '${AppUtils.formatDurationMillis(_adminLockRemainingMs)}',
          isError: true,
        );
      }
      return false;
    }
    if (!_adminEnabled) return true;
    if (!_accessVerified) {
      await _ensureAppAccess();
    }
    return _accessVerified;
  }

  void _openAddFlow() async {
    final allowed =
        await _requireAdmin('Ingresa tu PIN para agregar una aplicación');
    if (!allowed || !mounted) return;

    final existing =
        _blocks.map((r) => r['packageName'] as String).toSet();

    final app = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AppPickerScreen(excludedPackages: existing),
      ),
    );
    if (app == null || !mounted) return;
    final limit = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockEditScreen(
          appName: app['appName'] as String,
          packageName: app['packageName'] as String,
          isCreate: true,
        ),
      ),
    );
    if (limit == null) return;

    await _addBlock(
      app['packageName']! as String,
      app['appName']! as String,
      limit['dailyQuotaMinutes'] as int? ?? 30,
      limit: limit,
    );

    // Horarios se configuran desde la pantalla de edición.
  }

  Future<void> _openLimitEditor(Map<String, dynamic> r) async {
    final allowed =
        await _requireAdmin('Ingresa tu PIN para modificar límites');
    if (!allowed || !mounted) return;

    final limit = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => BlockEditScreen(
          appName: r['appName'],
          initial: r,
        ),
      ),
    );
    if (limit == null) return;
    if (limit['deleted'] == true) {
      final pkg = r['packageName']?.toString() ?? '';
      if (pkg.isNotEmpty && mounted) {
        setState(() {
          _blocks.removeWhere((x) => x['packageName'] == pkg);
        });
      }
      _refreshWidgetsSoon();
      _reloadBlocksSoon();
      return;
    }
    if (limit['schedulesChanged'] == true) {
      _scheduleDirty.add(r['packageName'].toString());
    }
    if (limit['dateBlocksChanged'] == true) {
      _dateBlockDirty.add(r['packageName'].toString());
    }

    final previous = Map<String, dynamic>.from(r);
    final pkg = r['packageName']?.toString() ?? '';
    final next = {
      ...r,
      'dailyQuotaMinutes': limit['dailyQuotaMinutes'] ?? r['dailyQuotaMinutes'],
      'limitType': limit['limitType'] ?? r['limitType'],
      'dailyMode': limit['dailyMode'] ?? r['dailyMode'],
      'dailyQuotas': limit['dailyQuotas'] ?? r['dailyQuotas'],
      'isEnabled': limit['isEnabled'] ?? r['isEnabled'],
      'weeklyQuotaMinutes':
          limit['weeklyQuotaMinutes'] ?? r['weeklyQuotaMinutes'],
      'weeklyResetDay': limit['weeklyResetDay'] ?? r['weeklyResetDay'],
      'weeklyResetHour': limit['weeklyResetHour'] ?? r['weeklyResetHour'],
      'weeklyResetMinute': limit['weeklyResetMinute'] ?? r['weeklyResetMinute'],
      'expiresAt':
          limit.containsKey('expiresAt') ? limit['expiresAt'] : r['expiresAt'],
    };
    if (mounted && pkg.isNotEmpty) {
      setState(() {
        final idx = _blocks.indexWhere((x) => x['packageName'] == pkg);
        if (idx >= 0) {
          _blocks[idx] = Map<String, dynamic>.from(next);
          _sortBlocks(_blocks);
        }
      });
    }
    try {
      await NativeService.updateBlock({
        'packageName': pkg,
        'dailyQuotaMinutes': next['dailyQuotaMinutes'],
        'isEnabled': next['isEnabled'],
        'macroType': 'LIMIT',
        'limitType': next['limitType'],
        'dailyMode': next['dailyMode'],
        'dailyQuotas': next['dailyQuotas'],
        'weeklyQuotaMinutes': next['weeklyQuotaMinutes'],
        'weeklyResetDay': next['weeklyResetDay'],
        'weeklyResetHour': next['weeklyResetHour'],
        'weeklyResetMinute': next['weeklyResetMinute'],
        'expiresAt': next['expiresAt'],
      });
      _refreshWidgetsSoon();
      _reloadBlocksSoon();
    } catch (_) {
      if (mounted && pkg.isNotEmpty) {
        setState(() {
          final idx = _blocks.indexWhere((x) => x['packageName'] == pkg);
          if (idx >= 0) {
            _blocks[idx] = previous;
            _sortBlocks(_blocks);
          }
        });
      }
      if (mounted) {
        context.showSnack('No se pudo guardar el cambio', isError: true);
      }
    }
  }

  double _progressFor(Map<String, dynamic> r) {
    final quotaMinutes = _quotaMinutesFor(r);
    if (quotaMinutes <= 0) return 0.0;
    final limitType = (r['limitType'] ?? 'daily').toString();
    if (limitType == 'weekly') {
      final usedWeek = (r['usedMinutesWeek'] as int?) ?? 0;
      return (usedWeek / quotaMinutes).clamp(0.0, 1.0);
    }

    final usedMillis = (r['usedMillis'] as num?)?.toDouble();
    if (usedMillis != null) {
      final quotaMillis = quotaMinutes * 60000.0;
      return (usedMillis / quotaMillis).clamp(0.0, 1.0);
    }
    final used = (r['usedMinutes'] as int).toDouble();
    return (used / quotaMinutes).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Límites activos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAddFlow,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Nueva'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_permissionsOk)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: _permissionsBanner(),
                ),
              ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else if (_blocks.isEmpty)
              SliverFillRemaining(child: _emptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                sliver: SliverList.separated(
                  itemCount: _blocks.length,
                  itemBuilder: (_, i) => RepaintBoundary(
                      child: _blockCard(_blocks[i])),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFlow,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Límites',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Límites diarios por app',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            height: 1,
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
  Widget _permissionsBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35), width: 1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Faltan permisos críticos',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PermissionsScreen()),
            ).then((_) => _checkPermissions()),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.warning.withValues(alpha: 0.2),
              foregroundColor: AppColors.onColor(AppColors.warning),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Configurar',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sin límites',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Toca "Nueva" para comenzar a\nconfigurar tus límites',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockCard(Map<String, dynamic> r) {
    final expired = r['isExpired'] == true || _isExpired(r);
    final blocked = !expired && (r['isBlocked'] as bool);
    final enabled = r['isEnabled'] as bool? ?? true;
    final statusLabel = expired
        ? 'VENCIDA'
        : blocked
            ? 'BLOQUEADA'
            : enabled
                ? 'ACTIVA'
                : 'PAUSADA';
    final statusColor = expired
        ? AppColors.warning
        : blocked
            ? AppColors.error
            : enabled
                ? AppColors.success
                : AppColors.textSecondary;

    return Card(
      child: ListTile(
        leading: _buildAppIcon(r),
        title: Text(
          r['appName'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
        onTap: () => _openLimitEditor(r),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _openLimitEditor(r);
            }
            if (value == 'delete') {
              _deleteBlock(r);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Eliminar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBlock(Map<String, dynamic> r) async {
    final pkg = r['packageName']?.toString();
    if (pkg == null || pkg.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar límite'),
        content: Text(
          '¿Eliminar "${r['appName'] ?? pkg}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await NativeService.deleteBlock(pkg);
      if (!mounted) return;
      setState(() {
        _blocks.removeWhere((x) => x['packageName'] == pkg);
      });
      _refreshWidgetsSoon();
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }


  Widget _buildAppIcon(Map<String, dynamic> r) {
    final pkg = r['packageName'] as String?;
    final cached = pkg != null ? _iconCache[pkg] : null;
    final bytes = cached ?? r['iconBytes'];
    if (bytes is Uint8List && bytes.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }
    if (pkg != null && !_iconLoading.contains(pkg)) {
      _iconLoading.add(pkg);
      NativeService.getAppIcon(pkg).then((icon) {
        if (!mounted) return;
        if (icon != null && icon.isNotEmpty) {
          setState(() {
            _iconCache[pkg] = icon;
            r['iconBytes'] = icon;
          });
        }
      }).whenComplete(() => _iconLoading.remove(pkg));
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.apps_rounded,
        size: 20,
        color: AppColors.textTertiary,
      ),
    );
  }

  int _quotaMinutesFor(Map<String, dynamic> r) {
    final limitType = (r['limitType'] ?? 'daily').toString();
    if (limitType == 'none') return 0;
    if (limitType == 'weekly') {
      return (r['weeklyQuotaMinutes'] as int?) ?? 0;
    }

    final dailyMode = (r['dailyMode'] ?? 'same').toString();
    if (dailyMode != 'per_day') {
      return (r['dailyQuotaMinutes'] as int?) ?? 0;
    }

    final day = _todayDayOfWeek();
    final map = _dailyQuotasMap(r['dailyQuotas']);
    return map[day] ?? 0;
  }

  bool _sameCardData(Map<String, dynamic> a, Map<String, dynamic> b) {
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    bool toBool(dynamic v) => v == true;

    return (a['packageName'] ?? '') == (b['packageName'] ?? '') &&
        (a['appName'] ?? '') == (b['appName'] ?? '') &&
        toInt(a['dailyQuotaMinutes']) == toInt(b['dailyQuotaMinutes']) &&
        toInt(a['weeklyQuotaMinutes']) == toInt(b['weeklyQuotaMinutes']) &&
        (a['limitType'] ?? 'daily') == (b['limitType'] ?? 'daily') &&
        (a['dailyMode'] ?? 'same') == (b['dailyMode'] ?? 'same') &&
        '${a['dailyQuotas'] ?? ''}' == '${b['dailyQuotas'] ?? ''}' &&
        toInt(a['scheduleCount']) == toInt(b['scheduleCount']) &&
        toInt(a['scheduleActiveCount']) == toInt(b['scheduleActiveCount']) &&
        toInt(a['dateBlockCount']) == toInt(b['dateBlockCount']) &&
        toInt(a['dateBlockActiveCount']) == toInt(b['dateBlockActiveCount']) &&
        toInt(a['usedMinutes']) == toInt(b['usedMinutes']) &&
        toInt(a['usedMillis']) == toInt(b['usedMillis']) &&
        toInt(a['usedMinutesWeek']) == toInt(b['usedMinutesWeek']) &&
        toBool(a['isEnabled']) == toBool(b['isEnabled']) &&
        toBool(a['isBlocked']) == toBool(b['isBlocked']) &&
        toBool(a['isExpired']) == toBool(b['isExpired']) &&
        (a['expiresAt']?.toString() ?? '') ==
            (b['expiresAt']?.toString() ?? '');
  }

  void _sortBlocks(List<Map<String, dynamic>> list) {
    bool isBlocked(Map<String, dynamic> r) =>
        (r['isBlocked'] as bool? ?? false) || _isExpired(r);

    bool isActive(Map<String, dynamic> r) {
      final enabled = r['isEnabled'] as bool? ?? true;
      final quota = _quotaMinutesFor(r);
      final scheduleActive = (r['scheduleActiveCount'] as int?) ?? 0;
      final dateActive = (r['dateBlockActiveCount'] as int?) ?? 0;
      return enabled &&
          !isBlocked(r) &&
          (quota > 0 || scheduleActive > 0 || dateActive > 0);
    }

    int statusRank(Map<String, dynamic> r) {
      if (isActive(r)) return 0; // activas
      if (isBlocked(r)) return 1; // bloqueadas
      return 2;
    }

    int endingSoonRank(Map<String, dynamic> r) {
      final quota = _quotaMinutesFor(r);
      if (quota <= 0) return 1;
      final limitType = (r['limitType'] ?? 'daily').toString();
      final used = limitType == 'weekly'
          ? (r['usedMinutesWeek'] as int? ?? 0)
          : (r['usedMinutes'] as int? ?? 0);
      final remaining = quota - used;
      if (remaining > 0 && remaining <= 15) return 0; // por terminar
      return 1;
    }

    int startingSoonRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final scheduleActive = (r['scheduleActiveCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      final dateActive = (r['dateBlockActiveCount'] as int?) ?? 0;
      final hasDirect = scheduleCount > 0 || dateCount > 0;
      final activeDirect = scheduleActive > 0 || dateActive > 0;
      if (hasDirect && !activeDirect) return 0; // por empezar
      return 1;
    }

    int directTypeRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      if (dateCount > 0 && scheduleCount == 0) return 0;
      if (scheduleCount > 0 && dateCount == 0) return 1;
      if (scheduleCount > 0 && dateCount > 0) return 2;
      return 3;
    }

    int typeRank(Map<String, dynamic> r) {
      final scheduleCount = (r['scheduleCount'] as int?) ?? 0;
      final dateCount = (r['dateBlockCount'] as int?) ?? 0;
      if (dateCount > 0 && scheduleCount == 0) return 0; // por fechas
      if (scheduleCount > 0 && dateCount == 0) return 1; // por horarios
      if (scheduleCount > 0 && dateCount > 0) return 2; // mixto
      if (_quotaMinutesFor(r) > 0) return 3; // solo cuota
      return 4;
    }

    list.sort((a, b) {
      if (_sortMode == 'name_asc') {
        final nameA = (a['appName'] ?? '').toString().toLowerCase();
        final nameB = (b['appName'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      }
      if (_sortMode == 'name_desc') {
        final nameA = (a['appName'] ?? '').toString().toLowerCase();
        final nameB = (b['appName'] ?? '').toString().toLowerCase();
        return nameB.compareTo(nameA);
      }
      if (_sortMode == 'usage_high') {
        final ua = _progressFor(a);
        final ub = _progressFor(b);
        if (ua != ub) return ub.compareTo(ua);
      }
      if (_sortMode == 'usage_low') {
        final ua = _progressFor(a);
        final ub = _progressFor(b);
        if (ua != ub) return ua.compareTo(ub);
      }
      if (_sortMode == 'blocked_first') {
        final ba = isBlocked(a);
        final bb = isBlocked(b);
        if (ba != bb) return ba ? -1 : 1;
      }
      if (_sortMode == 'active_first') {
        final aa = isActive(a);
        final ab = isActive(b);
        if (aa != ab) return aa ? -1 : 1;
      }
      if (_sortMode == 'ending_soon') {
        final ea = endingSoonRank(a);
        final eb = endingSoonRank(b);
        if (ea != eb) return ea.compareTo(eb);
      }
      if (_sortMode == 'starting_soon') {
        final pa = startingSoonRank(a);
        final pb = startingSoonRank(b);
        if (pa != pb) return pa.compareTo(pb);
      }
      if (_sortMode == 'dates_first') {
        final ta = directTypeRank(a);
        final tb = directTypeRank(b);
        if (ta != tb) return ta.compareTo(tb);
      }
      if (_sortMode == 'schedules_first') {
        final ta = directTypeRank(a);
        final tb = directTypeRank(b);
        if (ta != tb) {
          final sa = ta == 1
              ? 0
              : ta == 0
                  ? 1
                  : ta;
          final sb = tb == 1
              ? 0
              : tb == 0
                  ? 1
                  : tb;
          if (sa != sb) return sa.compareTo(sb);
        }
      }

      final sa = statusRank(a);
      final sb = statusRank(b);
      if (sa != sb) return sa.compareTo(sb);

      final ea = endingSoonRank(a);
      final eb = endingSoonRank(b);
      if (ea != eb) return ea.compareTo(eb);

      final pa = startingSoonRank(a);
      final pb = startingSoonRank(b);
      if (pa != pb) return pa.compareTo(pb);

      final ta = typeRank(a);
      final tb = typeRank(b);
      if (ta != tb) return ta.compareTo(tb);

      final nameA = (a['appName'] ?? '').toString().toLowerCase();
      final nameB = (b['appName'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  int _todayDayOfWeek() {
    final weekday = DateTime.now().weekday; // 1=Mon..7=Sun
    return weekday == 7 ? 1 : weekday + 1; // 1=Sun..7=Sat
  }

  Map<int, int> _dailyQuotasMap(dynamic value) {
    if (value == null) return {};
    if (value is String) {
      final map = <int, int>{};
      for (final pair in value.split(',')) {
        final parts = pair.split(':');
        if (parts.length != 2) continue;
        final day = int.tryParse(parts[0]);
        final minutes = int.tryParse(parts[1]);
        if (day == null || minutes == null) continue;
        map[day] = minutes;
      }
      return map;
    }
    if (value is Map) {
      final map = <int, int>{};
      value.forEach((k, v) {
        final day = int.tryParse(k.toString());
        final minutes = int.tryParse(v.toString());
        if (day == null || minutes == null) return;
        map[day] = minutes;
      });
      return map;
    }
    return {};
  }

}





