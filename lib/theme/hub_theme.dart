import 'package:flutter/material.dart';

/// IceDragon Glass palette for Dark Midnight Ice & Light Frosted Ice themes.
abstract final class DarkGlassPalette {
  static const bgTop = Color(0xFF070B1A);
  static const bgMid = Color(0xFF0C1430);
  static const bgBottom = Color(0xFF050814);

  static const purple = Color(0xFF8470FF);
  static const cyan = Color(0xFF2CE6FF);
  static const mint = Color(0xFF00E5A3);
  static const amber = Color(0xFFFFB547);
  static const coral = Color(0xFFFF5C7A);

  static const text = Colors.white;
  static const muted = Color(0xFF9EAAD0);

  static const glassFill = Color(0x14FFFFFF);
  static const glassFillElevated = Color(0x1EFFFFFF);
  static const glassBorder = Color(0x28FFFFFF);
  static const glassBorderBright = Color(0x42FFFFFF);

  static const cardSurface = Color(0xFF101730);
  static const cardBorder = Color(0xFF24315B);

  static const lightBgTop = Color(0xFFEAF2FF);
  static const lightBgBottom = Color(0xFFF6F9FF);
  static const lightCard = Color(0xECFFFFFF);
  static const lightBorder = Color(0xFFD6E2F5);
}

ThemeData _finishGlassTheme(
  ThemeData base, {
  required bool dark,
  required Color scaffoldBg,
  required Color navBg,
  required Color menuBg,
  required Color borderColor,
  required Color inputFill,
  required Color textMuted,
}) {
  final scheme = base.colorScheme;
  return base.copyWith(
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? DarkGlassPalette.cardSurface : DarkGlassPalette.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0x1CFFFFFF) : const Color(0x161E2B58),
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: navBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: dark
          ? DarkGlassPalette.cyan.withValues(alpha: 0.16)
          : DarkGlassPalette.purple.withValues(alpha: 0.14),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark
              ? DarkGlassPalette.cyan.withValues(alpha: 0.34)
              : DarkGlassPalette.purple.withValues(alpha: 0.25),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 22,
          color: selected
              ? (dark ? DarkGlassPalette.cyan : DarkGlassPalette.purple)
              : textMuted,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return base.textTheme.labelSmall?.copyWith(
          color: selected ? scheme.onSurface : textMuted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        );
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark
                ? DarkGlassPalette.purple.withValues(alpha: 0.28)
                : DarkGlassPalette.purple.withValues(alpha: 0.14);
          }
          return inputFill;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark ? Colors.white : DarkGlassPalette.purple;
          }
          return scheme.onSurface;
        }),
        textStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: inputFill,
      selectedColor: dark
          ? DarkGlassPalette.cyan.withValues(alpha: 0.20)
          : DarkGlassPalette.purple.withValues(alpha: 0.14),
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: menuBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: menuBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: borderColor),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: menuBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: dark ? DarkGlassPalette.cyan : DarkGlassPalette.purple,
          width: 1.6,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF161F3E) : const Color(0xFF1A2340),
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? DarkGlassPalette.cardBorder : Colors.transparent,
        ),
      ),
    ),
  );
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
        surfaceContainerHigh: const Color(0xFF151E3E),
        surfaceContainerHighest: const Color(0xFF1C274E),
        onSurface: Colors.white,
        onSurfaceVariant: DarkGlassPalette.muted,
        outline: const Color(0xFF2E3B6B),
        outlineVariant: DarkGlassPalette.cardBorder,
        secondaryContainer: DarkGlassPalette.cyan.withValues(alpha: 0.18),
        onSecondaryContainer: Colors.white,
        primaryContainer: DarkGlassPalette.purple.withValues(alpha: 0.24),
        onPrimaryContainer: const Color(0xFFECE9FF),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );

  return _finishGlassTheme(
    base,
    dark: true,
    scaffoldBg: DarkGlassPalette.bgBottom,
    navBg: const Color(0xE8090E20),
    menuBg: DarkGlassPalette.cardSurface,
    borderColor: DarkGlassPalette.cardBorder,
    inputFill: Colors.white.withValues(alpha: 0.05),
    textMuted: DarkGlassPalette.muted,
  );
}

ThemeData buildLightGlassTheme([String? fontFamily]) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: DarkGlassPalette.purple,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF5A45EE),
        secondary: const Color(0xFF0095CC),
        tertiary: const Color(0xFF00A878),
        surface: DarkGlassPalette.lightBgBottom,
        surfaceContainer: Colors.white,
        surfaceContainerHigh: const Color(0xFFF0F5FF),
        onSurface: const Color(0xFF101833),
        onSurfaceVariant: const Color(0xFF56638A),
        outlineVariant: DarkGlassPalette.lightBorder,
        secondaryContainer: const Color(0xFFE0F4FF),
        onSecondaryContainer: const Color(0xFF093A57),
        primaryContainer: const Color(0xFFECE9FF),
        onPrimaryContainer: const Color(0xFF27187E),
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );

  return _finishGlassTheme(
    base,
    dark: false,
    scaffoldBg: DarkGlassPalette.lightBgBottom,
    navBg: const Color(0xF2FFFFFF),
    menuBg: Colors.white,
    borderColor: DarkGlassPalette.lightBorder,
    inputFill: const Color(0xCCFFFFFF),
    textMuted: const Color(0xFF637096),
  );
}

/// Atmospheric IceDragon frost gradient & subtle radial glow backdrop.
class IceDragonBackdrop extends StatelessWidget {
  const IceDragonBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? const [
                          Color(0xFF09112A),
                          DarkGlassPalette.bgTop,
                          DarkGlassPalette.bgBottom,
                        ]
                      : const [
                          DarkGlassPalette.lightBgTop,
                          DarkGlassPalette.lightBgBottom,
                          Color(0xFFEDEFFF),
                        ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -90,
                    right: -60,
                    child: _AmbientGlow(
                      size: 260,
                      color: (dark
                              ? DarkGlassPalette.cyan
                              : const Color(0xFF38BDF8))
                          .withValues(alpha: dark ? 0.14 : 0.18),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: -80,
                    child: _AmbientGlow(
                      size: 240,
                      color: (dark
                              ? DarkGlassPalette.purple
                              : const Color(0xFF7C6BFF))
                          .withValues(alpha: dark ? 0.15 : 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  );
}

/// Translucent glassmorphic card with hairline frost border and soft depth.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.borderColor,
    this.fillColor,
    this.accentColor,
    this.dark = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Color? fillColor;
  final Color? accentColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg =
        fillColor ??
        (dark ? DarkGlassPalette.glassFill : DarkGlassPalette.lightCard);
    final border =
        borderColor ??
        (accentColor != null
            ? accentColor!.withValues(alpha: dark ? 0.44 : 0.35)
            : (dark
                  ? DarkGlassPalette.glassBorder
                  : DarkGlassPalette.lightBorder));

    Gradient? gradient;
    if (fillColor == null) {
      if (accentColor != null) {
        gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor!.withValues(alpha: dark ? 0.18 : 0.11),
            dark ? const Color(0x14FFFFFF) : Colors.white.withValues(alpha: 0.94),
          ],
        );
      } else if (dark) {
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x1BFFFFFF), Color(0x0BFFFFFF)],
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient,
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF283A7A).withValues(alpha: 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: gradient != null ? Colors.transparent : bg,
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
