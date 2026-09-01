import 'dart:math' as math;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/common.dart';
import 'package:flutter/material.dart';

typedef PopupAnchorResolver = Rect? Function();

typedef PopupOpen = void Function({Offset offset});

const _screenMargin = 16.0;

const _anchorOverlap = 8.0;

class CommonPopupRoute<T> extends PopupRoute<T> {
  CommonPopupRoute({
    required this.builder,
    required this.anchorOf,
    required this.barrierLabel,
  });

  final WidgetBuilder builder;
  final PopupAnchorResolver anchorOf;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  void _handleDismiss() {
    if (isCurrent) {
      navigator?.pop();
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const alignment = Alignment.topRight;
    final fade = animation.drive(CurveTween(curve: Curves.easeOut));
    final scale = animation.drive(CurveTween(curve: Curves.easeOutBack));
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: _handleDismiss,
          ),
        ),
        _PopupAnchorTracker(
          anchorOf: anchorOf,
          builder: (anchor, safeInsets, child) => CustomSingleChildLayout(
            delegate: _PopupLayoutDelegate(
              anchor: anchor,
              safeInsets: safeInsets,
            ),
            child: child,
          ),
          child: FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              alignment: alignment,
              scale: scale,
              child: SlideTransition(
                position: scale.drive(
                  Tween(begin: const Offset(0, -0.02), end: Offset.zero),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PopupAnchorTracker extends StatefulWidget {
  const _PopupAnchorTracker({
    required this.anchorOf,
    required this.builder,
    required this.child,
  });

  final PopupAnchorResolver anchorOf;
  final Widget Function(Rect anchor, EdgeInsets safeInsets, Widget child)
  builder;
  final Widget child;

  @override
  State<_PopupAnchorTracker> createState() => _PopupAnchorTrackerState();
}

class _PopupAnchorTrackerState extends State<_PopupAnchorTracker> {
  Rect? _anchor;
  bool _syncScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) {
      return;
    }
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) {
        return;
      }
      final anchor = widget.anchorOf();
      if (anchor == null || anchor == _anchor) {
        return;
      }
      setState(() {
        _anchor = anchor;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final anchor = _anchor ??= widget.anchorOf() ?? Rect.zero;
    return widget.builder(anchor, padding, widget.child);
  }
}

class _PopupLayoutDelegate extends SingleChildLayoutDelegate {
  const _PopupLayoutDelegate({required this.anchor, required this.safeInsets});

  final Rect anchor;
  final EdgeInsets safeInsets;

  EdgeInsets get _insets => safeInsets + const EdgeInsets.all(_screenMargin);

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final insets = _insets;
    return BoxConstraints.loose(
      Size(
        math.max(0.0, constraints.maxWidth - insets.horizontal),
        math.max(0.0, constraints.maxHeight - insets.vertical),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final insets = _insets;
    final maxX = size.width - insets.right - childSize.width;
    final maxY = size.height - insets.bottom - childSize.height;
    return Offset(
      (anchor.right - childSize.width).clamp(
        insets.left,
        math.max(insets.left, maxX),
      ),
      (anchor.top - _anchorOverlap).clamp(
        insets.top,
        math.max(insets.top, maxY),
      ),
    );
  }

  @override
  bool shouldRelayout(_PopupLayoutDelegate oldDelegate) {
    return oldDelegate.anchor != anchor || oldDelegate.safeInsets != safeInsets;
  }
}

class PopupController extends ValueNotifier<bool> {
  PopupController() : super(false);

  void open() {
    value = true;
  }

  void close() {
    value = false;
  }
}

class CommonPopupBox extends StatefulWidget {
  final Widget Function(PopupOpen open) targetBuilder;
  final Widget? popup;
  final WidgetBuilder? popupBuilder;

  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    this.popup,
    this.popupBuilder,
  }) : assert(popup != null || popupBuilder != null);

  @override
  State<CommonPopupBox> createState() => _CommonPopupBoxState();
}

class _CommonPopupBoxState extends State<CommonPopupBox> {
  Rect? _anchorOf(Offset offset) {
    if (!mounted) {
      return null;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) {
      return null;
    }
    final navigatorBox =
        Navigator.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final origin = renderBox.localToGlobal(Offset.zero, ancestor: navigatorBox);
    return (origin & renderBox.size).shift(offset);
  }

  void _open({Offset offset = Offset.zero}) {
    Navigator.of(context).push(
      CommonPopupRoute<void>(
        barrierLabel: utils.id,
        anchorOf: () => _anchorOf(offset),
        builder: (context) {
          if (widget.popupBuilder != null) {
            return widget.popupBuilder!(context);
          }
          return widget.popup!;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.targetBuilder(_open);
  }
}

class CommonPopupMenu extends StatelessWidget {
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double minItemVerticalPadding;
  final double fontSize;

  const CommonPopupMenu({
    super.key,
    required this.items,
    this.minWidth = 200,
    this.minItemVerticalPadding = 16,
    this.fontSize = 15,
  });

  Widget _popupMenuItem(
    BuildContext context, {
    required PopupMenuItemData item,
    required int index,
  }) {
    final onPressed = item.onPressed;
    final disabled = onPressed == null;
    final color = disabled
        ? context.colorScheme.onSurface.opacity30
        : context.colorScheme.onSurface;
    return InkWell(
      onTap: onPressed != null
          ? () {
              Navigator.of(context).pop();
              onPressed();
            }
          : null,
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: EdgeInsets.only(
          left: 16,
          right: 64,
          top: minItemVerticalPadding,
          bottom: minItemVerticalPadding,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: fontSize + 4, color: color),
              SizedBox(width: 16),
            ],
            Flexible(
              child: Text(
                item.label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontSize: fontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: IntrinsicWidth(
        child: Card(
          elevation: 12,
          color: context.colorScheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items.asMap().entries) ...[
                _popupMenuItem(context, item: item.value, index: item.key),
                if (item.value != items.last) Divider(height: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
