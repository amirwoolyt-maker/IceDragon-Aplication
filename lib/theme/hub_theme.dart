import 'package:flutter/material.dart';

/// IceDragon Glass palette for Dark Midnight Ice & Light Frosted Ice themes.
abstract final class DarkGlassPalette {
  static const bgTop = Color(0xFF070C1E);
  static const bgMid = Color(0xFF0B1432);
  static const bgBottom = Color(0xFF050914);

  // Harmonious matching palette: Ice Cyber & Arctic Aurora
  static const cyan = Color(0xFF00E5FF);
  static const purple = Color(0xFF8B5CF6);
  static const mint = Color(0xFF00F5A0);
  static const amber = Color(0xFFFFB800);
  static const coral = Color(0xFFFF477E);
  static const ruby = Color(0xFFF43F5E);
  static const blue = Color(0xFF3B82F6);

  static const text = Colors.white;
  static const muted = Color(0xFF94A3B8);

  static const glassFill = Color(0x18FFFFFF);
  static const glassFillElevated = Color(0x24FFFFFF);
  static const glassBorder = Color(0x3300E5FF);
  static const glassBorderBright = Color(0x5900E5FF);

  static const cardSurface = Color(0xFF0D152B);
  static const cardBorder = Color(0xFF1E2D56);

  static const lightBgTop = Color(0xFFEDF4FE);
  static const lightBgBottom = Color(0xFFF7FAFC);
  static const lightCard = Color(0xF4FFFFFF);
  static const lightBorder = Color(0xFFD4E2F4);
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

/// Atmospheric IceDragon frost gradient & multi-orb cyber aurora backdrop.
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? const [
                              Color(0xFF060B1A),
                              DarkGlassPalette.bgTop,
                              DarkGlassPalette.bgMid,
                              DarkGlassPalette.bgBottom,
                            ]
                          : const [
                              DarkGlassPalette.lightBgTop,
                              DarkGlassPalette.lightBgBottom,
                              Color(0xFFE2EDFC),
                            ],
                    ),
                  ),
                ),
                // Subtle high-tech frost lattice mesh to eliminate empty-screen feel
                CustomPaint(
                  painter: _CyberFrostLatticePainter(
                    dotColor: (dark ? Colors.white : const Color(0xFF1E3A8A))
                        .withValues(alpha: dark ? 0.045 : 0.035),
                  ),
                ),
                // Multi-orb harmonious aurora lighting
                Positioned(
                  top: -80,
                  right: -50,
                  child: _AmbientGlow(
                    size: 300,
                    color: (dark ? DarkGlassPalette.cyan : const Color(0xFF00B4D8))
                        .withValues(alpha: dark ? 0.16 : 0.15),
                  ),
                ),
                Positioned(
                  top: 180,
                  left: -70,
                  child: _AmbientGlow(
                    size: 260,
                    color: (dark
                            ? DarkGlassPalette.purple
                            : const Color(0xFF7C6BFF))
                        .withValues(alpha: dark ? 0.14 : 0.12),
                  ),
                ),
                Positioned(
                  bottom: 120,
                  right: -60,
                  child: _AmbientGlow(
                    size: 240,
                    color: (dark ? DarkGlassPalette.mint : const Color(0xFF00C988))
                        .withValues(alpha: dark ? 0.12 : 0.10),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: 20,
                  child: _AmbientGlow(
                    size: 280,
                    color: (dark ? const Color(0xFF1E3A8A) : const Color(0xFF93C5FD))
                        .withValues(alpha: dark ? 0.22 : 0.14),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Paints a faint, elegant cyber-frost dot lattice for futuristic depth.
class _CyberFrostLatticePainter extends CustomPainter {
  const _CyberFrostLatticePainter({required this.dotColor});

  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    const step = 32.0;
    for (double y = 16; y < size.height; y += step) {
      for (double x = 16; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CyberFrostLatticePainter oldDelegate) =>
      oldDelegate.dotColor != dotColor;
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
            accentColor!.withValues(alpha: dark ? 0.20 : 0.12),
            dark ? const Color(0x16FFFFFF) : Colors.white.withValues(alpha: 0.95),
          ],
        );
      } else if (dark) {
        gradient = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x22FFFFFF), Color(0x0CFFFFFF)],
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
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                if (accentColor != null)
                  BoxShadow(
                    color: accentColor!.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF283A7A).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: gradient != null ? Colors.transparent : bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: border, width: 1.1),
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
