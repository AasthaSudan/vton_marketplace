import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// One destination in a web panel sidebar (Seller Panel / Admin Panel).
class PanelSection {
  final String title;
  final IconData icon;

  /// Sub-areas listed on the section's page, from the blueprint sitemap.
  final List<String> items;

  /// Roadmap phase that delivers this section, e.g. `'Phase 2'`.
  final String phase;

  const PanelSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.phase,
  });
}

/// Responsive shell for the Clothsy web panels: a sidebar on wide screens and
/// a drawer on narrow ones, with the brand header and the selected section.
class PanelShell extends StatefulWidget {
  final String panelName;
  final List<PanelSection> sections;
  final Widget Function(BuildContext context, PanelSection section)?
  sectionBuilder;

  const PanelShell({
    super.key,
    required this.panelName,
    required this.sections,
    this.sectionBuilder,
  });

  static const double wideBreakpoint = 900;

  @override
  State<PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<PanelShell> {
  int _selected = 0;

  void _select(int index) => setState(() => _selected = index);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final section = widget.sections[_selected];
    final isWide =
        MediaQuery.sizeOf(context).width >= PanelShell.wideBreakpoint;

    final sidebar = _Sidebar(
      panelName: widget.panelName,
      sections: widget.sections,
      selected: _selected,
      onSelect: (i) {
        _select(i);
        if (!isWide) Navigator.of(context).maybePop();
      },
    );

    final content = widget.sectionBuilder != null
        ? widget.sectionBuilder!(context, section)
        : PanelSectionPlaceholder(section: section);

    return Scaffold(
      backgroundColor: colors.surfaceMuted,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: colors.surface,
              title: Text(
                section.title,
                style: AppTypography.h3(color: colors.textPrimary),
              ),
            ),
      drawer: isWide ? null : Drawer(child: sidebar),
      body: isWide
          ? Row(
              children: [
                SizedBox(width: 264, child: sidebar),
                Expanded(child: content),
              ],
            )
          : content,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String panelName;
  final List<PanelSection> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.panelName,
    required this.sections,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clothsy',
                    style: AppTypography.h1(color: colors.primary),
                  ),
                  Text(
                    panelName,
                    style: AppTypography.label(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < sections.length; i++)
              _SidebarTile(
                section: sections[i],
                isSelected: i == selected,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final PanelSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = isSelected ? colors.primary : colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? colors.surfaceMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(section.icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: AppTypography.bodyMedium(
                      color: isSelected ? colors.primary : colors.textPrimary,
                      weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder page for a panel section that is not built yet: shows the
/// planned sub-areas and the roadmap phase that delivers them.
class PanelSectionPlaceholder extends StatelessWidget {
  final PanelSection section;

  const PanelSectionPlaceholder({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Row(
          children: [
            Icon(section.icon, color: colors.primary, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                section.title,
                style: AppTypography.h1(color: colors.textPrimary),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Coming in ${section.phase}',
                style: AppTypography.label(color: colors.warning),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What you'll manage here",
                style: AppTypography.h3(color: colors.textPrimary),
              ),
              const SizedBox(height: 12),
              for (final item in section.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: colors.success,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: AppTypography.body(color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
