import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';

/// Compact workbench context that remains visible across destinations.
final class WorkbenchStatusBar extends StatelessWidget {
  const WorkbenchStatusBar({
    required this.projectName,
    required this.projectStatus,
    required this.terminalShortcut,
    required this.trailing,
    super.key,
  });

  final String? projectName;
  final String? projectStatus;
  final String terminalShortcut;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = MaestroThemeTokens.of(context);
    final foreground = tokens.statusBarSurface == scheme.primary
        ? scheme.onPrimary
        : tokens.statusBarSurface == scheme.primaryContainer
        ? scheme.onPrimaryContainer
        : scheme.onSurface;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: foreground,
      height: 1,
    );
    final selectedProjectName = projectName;
    final selectedProjectStatus = projectStatus;
    final contextLabel = selectedProjectName == null
        ? 'No project selected'
        : '$selectedProjectName, ${selectedProjectStatus ?? 'Status unknown'}';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Workbench status. $contextLabel. $terminalShortcut.',
      child: Container(
        height: tokens.statusBarHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: tokens.statusBarSurface,
          border: Border(top: BorderSide(color: tokens.subtleBorder)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DefaultTextStyle(
          style: labelStyle ?? TextStyle(color: foreground, height: 1),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: Row(
            children: <Widget>[
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    selectedProjectName ?? 'No project selected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (selectedProjectStatus != null) ...<Widget>[
                const SizedBox(width: 8),
                ExcludeSemantics(child: Text(selectedProjectStatus)),
              ],
              const SizedBox(width: 12),
              ExcludeSemantics(child: Text(terminalShortcut)),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
