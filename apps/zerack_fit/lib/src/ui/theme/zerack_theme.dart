import 'package:flutter/material.dart';

abstract final class Zk {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF0D0D0F);
  static const surfaceRaised = Color(0xFF16161A);
  static const surfaceTop = Color(0xFF1C1C20);
  static const text = Color(0xFFF5F5F5);
  static const muted = Color(0x94FFFFFF);
  static const faint = Color(0x5CFFFFFF);
  static const hairline = Color(0x12FFFFFF);
  static const hairlineStrong = Color(0x24FFFFFF);
  static const cyan = Color(0xFF22D3EE);
  static const cyanBright = Color(0xFF7DEEFF);
  static const cyanSoft = Color(0x1F22D3EE);
  static const cyanLine = Color(0x4D22D3EE);
  static const live = Color(0xFF00DC82);
  static const danger = Color(0xFFEF6B6B);
  static const amber = Color(0xFFFF9F43);

  static const fontFamily = 'SpaceGrotesk';

  static const glowText = [
    Shadow(color: Color(0x8CFFFFFF), blurRadius: 8),
    Shadow(color: Color(0x2EFFFFFF), blurRadius: 22),
  ];

  static const glowCyan = [
    Shadow(color: Color(0x9922D3EE), blurRadius: 10),
    Shadow(color: Color(0x3322D3EE), blurRadius: 26),
  ];

  static const stadium = StadiumBorder();
  static RoundedRectangleBorder rounded(double r, {Color? side}) =>
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: side == null ? BorderSide.none : BorderSide(color: side),
      );
}

abstract final class ZerackTheme {
  static const _scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Zk.text,
    onPrimary: Color(0xFF0B0B0C),
    primaryContainer: Color(0xFF0B2E35),
    onPrimaryContainer: Zk.cyanBright,
    secondary: Zk.cyan,
    onSecondary: Color(0xFF00161A),
    secondaryContainer: Color(0xFF0B2E35),
    onSecondaryContainer: Zk.cyanBright,
    tertiary: Zk.live,
    onTertiary: Color(0xFF00160C),
    error: Zk.danger,
    onError: Color(0xFF1A0505),
    surface: Zk.surface,
    onSurface: Zk.text,
    onSurfaceVariant: Zk.muted,
    surfaceContainerLowest: Zk.black,
    surfaceContainerLow: Color(0xFF0B0B0D),
    surfaceContainer: Zk.surface,
    surfaceContainerHigh: Zk.surfaceRaised,
    surfaceContainerHighest: Zk.surfaceTop,
    outline: Color(0xFF3C3C43),
    outlineVariant: Zk.hairline,
    shadow: Zk.black,
    scrim: Zk.black,
    inverseSurface: Zk.text,
    onInverseSurface: Color(0xFF0B0B0C),
    inversePrimary: Color(0xFF0B0B0C),
    surfaceTint: Colors.transparent,
  );

  static TextStyle _t(
    double size,
    FontWeight weight, {
    double spacing = 0,
    double height = 1.4,
    Color color = Zk.text,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: Zk.fontFamily,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    height: height,
    color: color,
    shadows: shadows,
  );

  static final _textTheme = TextTheme(
    displayLarge: _t(
      72,
      FontWeight.w600,
      spacing: -2,
      height: 1.05,
      shadows: Zk.glowText,
    ),
    displayMedium: _t(
      56,
      FontWeight.w600,
      spacing: -1.5,
      height: 1.05,
      shadows: Zk.glowText,
    ),
    displaySmall: _t(36, FontWeight.w600, spacing: -1, height: 1.15),
    headlineLarge: _t(30, FontWeight.w600, spacing: -0.6, height: 1.2),
    headlineMedium: _t(26, FontWeight.w600, spacing: -0.5, height: 1.2),
    headlineSmall: _t(22, FontWeight.w600, spacing: -0.4, height: 1.25),
    titleLarge: _t(18, FontWeight.w600, spacing: -0.2, height: 1.3),
    titleMedium: _t(15, FontWeight.w500, spacing: 0, height: 1.35),
    titleSmall: _t(13, FontWeight.w500, spacing: 0.1, height: 1.35),
    bodyLarge: _t(
      15.5,
      FontWeight.w400,
      height: 1.5,
      color: const Color(0xE6FFFFFF),
    ),
    bodyMedium: _t(
      14,
      FontWeight.w400,
      height: 1.5,
      color: const Color(0xDEFFFFFF),
    ),
    bodySmall: _t(12, FontWeight.w400, height: 1.45, color: Zk.muted),
    labelLarge: _t(14, FontWeight.w600, spacing: 0.2, height: 1.2),
    labelMedium: _t(12, FontWeight.w500, spacing: 0.6, height: 1.2),
    labelSmall: _t(10.5, FontWeight.w500, spacing: 1.2, height: 1.2),
  );

  static OutlineInputBorder _inputBorder(Color c, [double w = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  static WidgetStateProperty<T> _by<T>(
    T normal, {
    T? disabled,
    T? pressed,
    T? hovered,
    T? focused,
  }) => WidgetStateProperty.resolveWith((s) {
    if (s.contains(WidgetState.disabled) && disabled != null) return disabled;
    if (s.contains(WidgetState.pressed) && pressed != null) return pressed;
    if (s.contains(WidgetState.hovered) && hovered != null) return hovered;
    if (s.contains(WidgetState.focused) && focused != null) return focused;
    return normal;
  });

  static const _buttonPadding = EdgeInsets.symmetric(
    horizontal: 22,
    vertical: 14,
  );

  static final ButtonStyle filledStyle = ButtonStyle(
    backgroundColor: _by(Zk.text, disabled: const Color(0x14FFFFFF)),
    foregroundColor: _by(
      const Color(0xFF0B0B0C),
      disabled: const Color(0x4DFFFFFF),
    ),
    overlayColor: _by(
      Colors.transparent,
      pressed: const Color(0x1F000000),
      hovered: const Color(0x14000000),
    ),
    elevation: _by(0.0),
    shadowColor: _by(const Color(0x29FFFFFF)),
    surfaceTintColor: _by(Colors.transparent),
    shape: _by<OutlinedBorder>(Zk.stadium),
    padding: _by<EdgeInsetsGeometry>(_buttonPadding),
    minimumSize: _by(const Size(64, 46)),
    textStyle: _by(_t(14, FontWeight.w600, spacing: 0.1, height: 1.2)),
    side: _by<BorderSide?>(null),
  );

  static final ButtonStyle accentStyle = ButtonStyle(
    backgroundColor: _by(Zk.cyanSoft, disabled: const Color(0x0FFFFFFF)),
    foregroundColor: _by(Zk.cyan, disabled: const Color(0x4DFFFFFF)),
    overlayColor: _by(
      Colors.transparent,
      pressed: const Color(0x3322D3EE),
      hovered: const Color(0x1F22D3EE),
    ),
    elevation: _by(0.0),
    shadowColor: _by(Colors.transparent),
    surfaceTintColor: _by(Colors.transparent),
    shape: _by<OutlinedBorder>(Zk.stadium),
    side: _by<BorderSide?>(
      const BorderSide(color: Zk.cyanLine),
      disabled: const BorderSide(color: Zk.hairline),
    ),
    padding: _by<EdgeInsetsGeometry>(_buttonPadding),
    minimumSize: _by(const Size(64, 46)),
    textStyle: _by(_t(14, FontWeight.w600, spacing: 0.1, height: 1.2)),
  );

  static final ButtonStyle outlinedStyle = ButtonStyle(
    backgroundColor: _by(Colors.transparent),
    foregroundColor: _by(Zk.text, disabled: const Color(0x4DFFFFFF)),
    overlayColor: _by(
      Colors.transparent,
      pressed: const Color(0x1AFFFFFF),
      hovered: const Color(0x0FFFFFFF),
    ),
    elevation: _by(0.0),
    shape: _by<OutlinedBorder>(Zk.stadium),
    side: _by<BorderSide?>(
      const BorderSide(color: Zk.hairlineStrong),
      disabled: const BorderSide(color: Zk.hairline),
      focused: const BorderSide(color: Zk.cyan),
    ),
    padding: _by<EdgeInsetsGeometry>(_buttonPadding),
    minimumSize: _by(const Size(64, 46)),
    textStyle: _by(_t(14, FontWeight.w500, spacing: 0.1, height: 1.2)),
  );

  static final ButtonStyle textStyle = ButtonStyle(
    foregroundColor: _by(Zk.cyan, disabled: const Color(0x4DFFFFFF)),
    overlayColor: _by(
      Colors.transparent,
      pressed: const Color(0x2622D3EE),
      hovered: const Color(0x1422D3EE),
    ),
    shape: _by<OutlinedBorder>(Zk.stadium),
    padding: _by<EdgeInsetsGeometry>(
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textStyle: _by(_t(14, FontWeight.w600, spacing: 0.1, height: 1.2)),
  );

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _scheme,
      fontFamily: Zk.fontFamily,
      textTheme: _textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Zk.surface,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: Zk.hairline,
    );
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Zk.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: _t(18, FontWeight.w600, spacing: -0.2),
        iconTheme: const IconThemeData(color: Zk.text),
      ),
      cardTheme: CardThemeData(
        color: Zk.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: Zk.rounded(18, side: Zk.hairline),
      ),
      dividerTheme: const DividerThemeData(
        color: Zk.hairline,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: Zk.muted,
        textColor: Zk.text,
        titleTextStyle: _t(15, FontWeight.w500),
        subtitleTextStyle: _t(12.5, FontWeight.w400, color: Zk.muted),
        shape: Zk.rounded(14),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
      textButtonTheme: TextButtonThemeData(style: textStyle),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: _by(
            Colors.transparent,
            pressed: const Color(0x1FFFFFFF),
            hovered: const Color(0x14FFFFFF),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Zk.surfaceRaised,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: _t(14, FontWeight.w400, color: Zk.muted),
        floatingLabelStyle: _t(13, FontWeight.w500, color: Zk.cyan),
        hintStyle: _t(14, FontWeight.w400, color: Zk.faint),
        border: _inputBorder(Zk.hairline),
        enabledBorder: _inputBorder(Zk.hairline),
        focusedBorder: _inputBorder(Zk.cyan),
        errorBorder: _inputBorder(Zk.danger),
        focusedErrorBorder: _inputBorder(Zk.danger),
        disabledBorder: _inputBorder(Zk.hairline),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Zk.cyan,
        selectionColor: Color(0x4022D3EE),
        selectionHandleColor: Zk.cyan,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: Zk.cyanSoft,
        indicatorShape: Zk.stadium,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? Zk.cyan : Zk.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => _t(
            10.5,
            s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            spacing: 0.9,
            height: 1.1,
            color: s.contains(WidgetState.selected) ? Zk.cyan : Zk.muted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Zk.surfaceTop,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Zk.rounded(20, side: Zk.hairlineStrong),
        titleTextStyle: _t(20, FontWeight.w600, spacing: -0.3),
        contentTextStyle: _t(
          14,
          FontWeight.w400,
          height: 1.5,
          color: const Color(0xDEFFFFFF),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Zk.surfaceTop,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Zk.surfaceTop,
        modalBarrierColor: Color(0xB3000000),
        showDragHandle: true,
        dragHandleColor: Zk.hairlineStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          side: BorderSide(color: Zk.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Zk.surfaceTop,
        contentTextStyle: _t(14, FontWeight.w500),
        actionTextColor: Zk.cyan,
        behavior: SnackBarBehavior.floating,
        shape: Zk.rounded(14, side: Zk.hairlineStrong),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: Zk.cyanSoft,
        disabledColor: Colors.transparent,
        side: const BorderSide(color: Zk.hairlineStrong),
        shape: Zk.stadium,
        labelStyle: _t(13, FontWeight.w500),
        secondaryLabelStyle: _t(13, FontWeight.w600, color: Zk.cyan),
        checkmarkColor: Zk.cyan,
        iconTheme: const IconThemeData(color: Zk.muted, size: 16),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Zk.cyanSoft
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Zk.cyan : Zk.muted,
          ),
          side: _by<BorderSide?>(const BorderSide(color: Zk.hairlineStrong)),
          overlayColor: _by(
            Colors.transparent,
            pressed: const Color(0x1F22D3EE),
            hovered: const Color(0x0F22D3EE),
          ),
          textStyle: _by(_t(13, FontWeight.w500, height: 1.2)),
          shape: _by<OutlinedBorder>(Zk.stadium),
        ),
        selectedIcon: const Icon(Icons.check, size: 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Zk.black : Zk.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Zk.cyan
              : const Color(0x1AFFFFFF),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Zk.cyan : Zk.hairlineStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? Zk.cyan : Colors.transparent,
        ),
        checkColor: _by(Zk.black),
        side: const BorderSide(color: Color(0x66FFFFFF), width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Zk.cyan
              : const Color(0x66FFFFFF),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Zk.cyan,
        inactiveTrackColor: const Color(0x1FFFFFFF),
        thumbColor: Zk.text,
        overlayColor: const Color(0x2622D3EE),
        activeTickMarkColor: Zk.black,
        inactiveTickMarkColor: const Color(0x33FFFFFF),
        valueIndicatorColor: Zk.surfaceTop,
        valueIndicatorTextStyle: _t(13, FontWeight.w500),
        trackHeight: 3,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Zk.cyan,
        linearTrackColor: Color(0x14FFFFFF),
        circularTrackColor: Color(0x14FFFFFF),
        linearMinHeight: 4,
        borderRadius: BorderRadius.all(Radius.circular(99)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Zk.surfaceTop,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Zk.hairlineStrong),
        ),
        textStyle: _t(12, FontWeight.w500),
      ),
    );
  }
}
