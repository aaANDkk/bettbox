import 'dart:async';
import 'dart:math';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'common.dart';

const _enterStaggerLimit = 8;
const _enterStaggerStep = Duration(milliseconds: 20);
const _enterSlideBase = 32.0;
const _enterSlideStep = 8.0;
final _enterWindow = commonDuration + _enterStaggerStep * _enterStaggerLimit;

class ProxiesListView extends ConsumerWidget {
  const ProxiesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(proxiesListStateProvider);

    if (state.groups.isEmpty) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }

    return _ProxyGroupsList(
      groups: state.groups,
      columns: state.columns,
      cardType: state.proxyCardType,
      sortType: state.proxiesSortType,
      sortNum: state.sortNum,
      currentUnfoldSet: state.currentUnfoldSet,
    );
  }
}

class _ProxyGroupsList extends ConsumerStatefulWidget {
  final List<Group> groups;
  final int columns;
  final ProxyCardType cardType;
  final ProxiesSortType sortType;
  final num sortNum;
  final Set<String> currentUnfoldSet;

  const _ProxyGroupsList({
    required this.groups,
    required this.columns,
    required this.cardType,
    required this.sortType,
    required this.sortNum,
    required this.currentUnfoldSet,
  });

  @override
  ConsumerState<_ProxyGroupsList> createState() => _ProxyGroupsListState();
}

class _ProxyGroupsListState extends ConsumerState<_ProxyGroupsList> {
  final ScrollController _scrollController = ScrollController();
  String? _enterGroupName;
  Timer? _enterTimer;

  @override
  void dispose() {
    _stopEnterAnimated();
    _scrollController.dispose();
    super.dispose();
  }

  void _startEnterAnimated(String groupName) {
    _enterTimer?.cancel();
    _enterGroupName = groupName;
    _enterTimer = Timer(_enterWindow, _stopEnterAnimated);
  }

  void _stopEnterAnimated() {
    _enterTimer?.cancel();
    _enterTimer = null;
    _enterGroupName = null;
  }

  void _handleToggle(String groupName) {
    final tempUnfoldSet = Set<String>.from(widget.currentUnfoldSet);
    if (tempUnfoldSet.contains(groupName)) {
      tempUnfoldSet.remove(groupName);
      _stopEnterAnimated();
    } else {
      tempUnfoldSet.add(groupName);
      _startEnterAnimated(groupName);
    }
    globalState.appController.updateCurrentUnfoldSet(tempUnfoldSet);
  }

  double _getHeaderHeight() {
    final measure = globalState.measure;
    final contentRowHeight = [
      40.0,
      measure.titleMediumHeight + 4 + measure.labelMediumHeight,
    ].reduce((a, b) => a > b ? a : b);
    return 28.0 + contentRowHeight;
  }

  void _scrollToSelected(String groupName) {
    if (!_scrollController.hasClients) return;
    final selectedName = ref
        .read(getSelectedProxyNameProvider(groupName))
        .getSafeValue('');
    if (selectedName.isEmpty) return;

    final headerHeight = _getHeaderHeight() + 8.0;
    final rowHeight = getItemHeight(widget.cardType) + 8.0;

    var targetOffset = 16.0;
    for (final group in widget.groups) {
      if (group.name == groupName) {
        targetOffset += headerHeight;
        final sortedProxies = globalState.appController.getSortProxies(
          proxies: group.all,
          sortType: widget.sortType,
          testUrl: group.testUrl,
        );
        final proxyIndex =
            sortedProxies.indexWhere((p) => p.name == selectedName);
        if (proxyIndex >= 0) {
          final rowIndex = proxyIndex ~/ widget.columns;
          targetOffset += rowIndex * rowHeight;
        }
        break;
      }
      targetOffset += headerHeight;
      if (widget.currentUnfoldSet.contains(group.name)) {
        final rowCount =
            (group.all.length + widget.columns - 1) ~/ widget.columns;
        targetOffset += rowCount * rowHeight;
      }
    }

    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
  }

  Widget _buildProxyRow({
    required Group group,
    required List<Proxy> proxies,
    required int rowIndex,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final groupName = group.name;
    final enterAnimated = _enterGroupName == groupName;
    final cardWidgets = <Widget>[];
    for (var i = 0; i < columns; i++) {
      if (i < proxies.length) {
        final proxy = proxies[i];
        final card = ProxyCard(
          key: ValueKey('$groupName.${proxy.name}'),
          proxy: proxy,
          groupName: groupName,
          type: cardType,
          groupType: group.type,
          testUrl: group.testUrl,
        );
        if (!enterAnimated) {
          cardWidgets.add(Expanded(child: card));
        } else {
          final stagger = min(
            rowIndex * columns + i,
            _enterStaggerLimit,
          );
          cardWidgets.add(
            Expanded(
              child: FadeSlideEnterBox(
                delay: _enterStaggerStep * stagger,
                distance: _enterSlideBase + _enterSlideStep * stagger,
                child: card,
              ),
            ),
          );
        }
      } else {
        cardWidgets.add(const Expanded(child: SizedBox()));
      }
    }

    final rowChildren = <Widget>[];
    for (var i = 0; i < cardWidgets.length; i++) {
      rowChildren.add(cardWidgets[i]);
      if (i < cardWidgets.length - 1) {
        rowChildren.add(const SizedBox(width: 8));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: SizedBox(
        height: getItemHeight(cardType),
        child: Row(children: rowChildren),
      ),
    );
  }

  Widget _buildGroup(
    BuildContext context, {
    required Group group,
    required bool isExpand,
    required int columns,
    required ProxyCardType cardType,
  }) {
    final sortedProxies = isExpand
        ? globalState.appController.getSortProxies(
            proxies: group.all,
            sortType: widget.sortType,
            testUrl: group.testUrl,
          )
        : const <Proxy>[];

    final rows = <List<Proxy>>[];
    if (isExpand) {
      for (var i = 0; i < sortedProxies.length; i += columns) {
        final end = (i + columns < sortedProxies.length)
            ? i + columns
            : sortedProxies.length;
        rows.add(sortedProxies.sublist(i, end));
      }
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: _GroupHeader(
              key: ValueKey('header_${group.name}'),
              group: group,
              isExpand: isExpand,
              onToggle: () => _handleToggle(group.name),
              cardType: cardType,
              columns: columns,
              onScrollToSelected: () => _scrollToSelected(group.name),
            ),
          ),
        ),
        if (isExpand)
          SliverFixedExtentList(
            itemExtent: getItemHeight(cardType) + 8.0,
            delegate: SliverChildBuilderDelegate(
              (_, index) => _buildProxyRow(
                group: group,
                proxies: rows[index],
                rowIndex: index,
                columns: columns,
                cardType: cardType,
              ),
              childCount: rows.length,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);

    return CommonScrollBar(
      controller: _scrollController,
      child: CustomScrollView(
        key: const PageStorageKey<String>('proxies_list'),
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          for (final group in widget.groups)
            _buildGroup(
              context,
              group: group,
              isExpand: widget.currentUnfoldSet.contains(group.name),
              columns: widget.columns,
              cardType: widget.cardType,
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 16 +
                  (isMobileView
                      ? getFloatingBottomBarReserveHeight(context)
                      : 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends ConsumerWidget {
  final Group group;
  final bool isExpand;
  final VoidCallback onToggle;
  final ProxyCardType cardType;
  final int columns;
  final VoidCallback? onScrollToSelected;

  const _GroupHeader({
    super.key,
    required this.group,
    required this.isExpand,
    required this.onToggle,
    required this.cardType,
    required this.columns,
    this.onScrollToSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconStyle = ref.watch(
      proxiesStyleSettingProvider.select((s) => s.iconStyle),
    );
    final icon = ref.watch(proxyIconProvider(group.name));
    final selectedProxyName = ref
        .watch(getSelectedProxyNameProvider(group.name))
        .getSafeValue('');

    final selectedProxyIcon = ref.watch(
      proxyIconProvider(selectedProxyName),
    );

    return CommonCard(
      radius: 20,
      type: CommonCardType.filled,
      onPressed: globalState.isAndroidTV ? null : onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildIcon(context, iconStyle, icon),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiText(group.name, style: context.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        group.type.name,
                        style: context.textTheme.labelMedium?.toLight,
                      ),
                      if (selectedProxyName.isNotEmpty) ...[
                        Text(
                          '  •  ',
                          style: context.textTheme.labelMedium?.toLight,
                        ),
                        if (selectedProxyIcon.isNotEmpty) ...[
                          CommonTargetIcon(
                            src: selectedProxyIcon,
                            size: globalState.measure.labelMediumHeight,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: EmojiText(
                            selectedProxyName,
                            style: context.textTheme.labelMedium?.toLight,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isExpand) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.adjust),
                onPressed: onScrollToSelected,
                tooltip: appLocalizations.locate,
              ),
              AnimatedBuilder(
                animation: delayTestCoordinator,
                builder: (_, _) {
                  final isTestingThisGroup = delayTestCoordinator
                      .isTestingGroup(group.name);
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: isTestingThisGroup
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_ping),
                    onPressed: delayTestCoordinator.isTesting
                        ? null
                        : () => _delayTest(context),
                    tooltip: appLocalizations.startTest,
                  );
                },
              ),
            ],
            IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              icon: CommonExpandIcon(expand: isExpand),
              onPressed: onToggle,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.focused)) {
                    return context.colorScheme.primary.withValues(alpha: 0.2);
                  }
                  return null;
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, ProxiesIconStyle style, String icon) {
    if (style == ProxiesIconStyle.none) return const SizedBox();
    const iconSize = 40.0;
    if (style == ProxiesIconStyle.standard) {
      return Container(
        margin: const EdgeInsets.only(right: 16),
        width: iconSize,
        height: iconSize,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colorScheme.secondaryContainer,
        ),
        clipBehavior: Clip.antiAlias,
        child: CommonTargetIcon(src: icon, size: iconSize - 12),
      );
    }
    return Container(
      margin: const EdgeInsets.only(right: 16),
      width: iconSize,
      height: iconSize,
      alignment: Alignment.center,
      child: CommonTargetIcon(src: icon, size: iconSize - 8),
    );
  }

  Future<void> _delayTest(BuildContext context) async {
    await delayTest(group.all, testUrl: group.testUrl, groupName: group.name);
  }
}
