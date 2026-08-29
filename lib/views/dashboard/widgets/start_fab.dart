import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/add_profile.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StartFab extends ConsumerStatefulWidget {
  const StartFab({super.key});

  @override
  ConsumerState<StartFab> createState() => _StartFabState();
}

class _StartFabState extends ConsumerState<StartFab> {
  bool _isDisabled = false;
  bool? _optimisticStart;

  Future<void> _handleStart() async {
    if (_isDisabled) return;
    final isStart = ref.read(runTimeProvider) != null;
    final newState = !isStart;
    setState(() {
      _isDisabled = true;
      _optimisticStart = newState;
    });

    try {
      await globalState.appController.updateStatus(newState);
    } catch (e) {
      commonPrint.log('updateStatus failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDisabled = false;
          _optimisticStart = null;
        });
      }
    }
  }

  void _handleShowAddProfile() {
    showExtend(
      context,
      builder: (_, type) {
        return AdaptiveSheetScaffold(
          type: type,
          body: AddProfileView(context: context),
          title: appLocalizations.add,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(startButtonSelectorStateProvider);
    final canPress = state.isInit && state.hasProfile && !_isDisabled;
    final hasNoProfile = state.isInit && !state.hasProfile && !_isDisabled;

    return ValueListenableBuilder<int>(
      valueListenable: dashboardRefreshManager.tick1s,
      builder: (_, _, _) {
        final runTime = ref.read(runTimeProvider);
        final isStart = runTime != null;
        final displayStart = _optimisticStart ?? isStart;
        final showAddIcon = hasNoProfile;
        final labelText = showAddIcon
            ? appLocalizations.addProfile
            : displayStart
            ? _formatRunTime(runTime)
            : appLocalizations.startRunning;
        final icon = showAddIcon
            ? Icons.add
            : displayStart
            ? Icons.pause
            : Icons.play_arrow;
        return FloatingActionButton.extended(
          heroTag: null,
          onPressed: canPress
              ? _handleStart
              : hasNoProfile
                  ? _handleShowAddProfile
                  : null,
          icon: Icon(icon),
          label: Text(
            labelText,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }

  String _formatRunTime(int? timeStamp) {
    if (timeStamp == null) return '00:00:00';

    final diff = timeStamp / 1000;
    int inHours = (diff / 3600).floor();
    int inMinutes = (diff / 60 % 60).floor();
    int inSeconds = (diff % 60).floor();

    if (inHours > 999) {
      inHours = 999;
      inMinutes = 59;
      inSeconds = 59;
    }

    final hourStr = inHours < 100
        ? inHours.toString().padLeft(2, '0')
        : inHours.toString().padLeft(3, '0');

    return '$hourStr:${inMinutes.toString().padLeft(2, '0')}:${inSeconds.toString().padLeft(2, '0')}';
  }
}
