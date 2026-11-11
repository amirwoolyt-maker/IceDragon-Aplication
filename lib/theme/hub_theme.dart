import 'package:flutter/material.dart';

/// Dark Glassmorphism palette preserved for App Hub UI.
abstract final class DarkGlassPalette {
  static const bgTop = Color(0xFF0A0D1D);
  static const bgMid = Color(0xFF0D132B);
  static const bgBottom = Color(0xFF060812);

  static const purple = Color(0xFF816BFF);
  static const cyan = Color(0xFF00D2FF);
  static const mint = Color(0xFF00E5A3);
  static const amber = Color(0xFFFFB547);
  static const coral = Color(0xFFFF5C7A);

  static const text = Colors.white;
  static const muted = Color(0xFF9EA8CE);

  static const glassFill = Color(0x14FFFFFF);
  static const glassFillElevated = Color(0x1CFFFFFF);
  static const glassBorder = Color(0x24FFFFFF);
  static const glassBorderBright = Color(0x3DFFFFFF);

  static const cardSurface = Color(0xFF12172D);
  static const cardBorder = Color(0xFF232B4D);
}

ThemeData buildDarkGlassTheme([String? fontFamily]) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: DarkGlassPalette.purple,
        brightness: Brightness.dark,
      ).copyWith(
        primary: DarkGlassPalette.purple,
        secondary: DarkGlassPalette.cyan,
        tertiary: DarkGlassPalette.mint,
        surface: DarkGlassPalette.bgBottom,
        surfaceContainer: DarkGlassPalette.cardSurface,
        surfaceContainerHigh: const Color(0xFF171E3A),
        surfaceContainerHighest: const Color(0xFF1F274B),
        onSurface: Colors.white,
        onSurfaceVariant: DarkGlassPalette.muted,
        outline: const Color(0xFF2E3861),
        outlineVariant: DarkGlassPalette.cardBorder,
        secondaryContainer: DarkGlassPalette.purple.withValues(alpha: 0.20),
        onSecondaryContainer: Colors.white,
        primaryContainer: DarkGlassPalette.purple.withValues(alpha: 0.24),
        onPrimaryContainer: const Color(0xFFECE9FF),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: DarkGlassPalette.bgBottom,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: DarkGlassPalette.bgTop,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: DarkGlassPalette.cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DarkGlassPalette.cardBorder),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0x1FFFFFFF),
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xEE080B18),
      surfaceTintColor: Colors.transparent,
      indicatorColor: DarkGlassPalette.purple.withValues(alpha: 0.24),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? Colors.white : DarkGlassPalette.muted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return base.textTheme.labelMedium?.copyWith(
          color: selected ? Colors.white : DarkGlassPalette.muted,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: DarkGlassPalette.cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DarkGlassPalette.cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: DarkGlassPalette.cardBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DarkGlassPalette.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DarkGlassPalette.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: DarkGlassPalette.cyan,
          width: 1.5,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A2242),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: DarkGlassPalette.cardBorder),
      ),
    ),
  );
}

ThemeData buildLightGlassTheme([String? fontFamily]) {
  final scheme = ColorScheme.fromSeed(
    seedColor: DarkGlassPalette.purple,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );
}

/// Translucent glassmorphic card with hairline border and subtle depth.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.borderColor,
    this.fillColor,
    this.dark = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Color? fillColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg =
        fillColor ??
        (dark ? DarkGlassPalette.glassFill : const Color(0xD9FFFFFF));
    final border =
        borderColor ??
        (dark ? DarkGlassPalette.glassBorder : const Color(0x16202A66));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: dark && fillColor == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x19FFFFFF), Color(0x0BFFFFFF)],
              )
            : null,
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF2A3375).withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: dark && fillColor == null ? Colors.transparent : bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
