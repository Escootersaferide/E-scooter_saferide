import 'package:material_ui/material_ui.dart';

const saferideDarkCardColor = Color(0xFF20332F);

ThemeData saferideTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: const Color(0xFF149881),
    primary: dark ? const Color(0xFF77DAC4) : const Color(0xFF0C7867),
    onPrimary: dark ? const Color(0xFF102D28) : Colors.white,
    primaryContainer: dark ? const Color(0xFF274842) : const Color(0xFFE4F4EE),
    onPrimaryContainer: dark
        ? const Color(0xFFDCF7EF)
        : const Color(0xFF163A33),
    surface: dark ? const Color(0xFF142423) : const Color(0xFFF3F6F5),
    surfaceContainerLow: dark ? saferideDarkCardColor : Colors.white,
  );

  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(backgroundColor: colors.surface),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class SaferideScaffold extends StatelessWidget {
  const SaferideScaffold({
    super.key,
    required this.child,
    this.scrollKey,
    this.actions = const [],
  });

  final Widget child;
  final Key? scrollKey;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop == true;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: 'Назад',
                icon: const BackButtonIcon(),
              )
            : null,
        centerTitle: false,
        title: Tooltip(
          message: 'На главную',
          child: Semantics(
            button: true,
            label: 'На главную',
            child: InkWell(
              key: const ValueKey('saferide_home_logo'),
              borderRadius: BorderRadius.circular(10),
              onTap: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    const Text('saferide'),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              key: scrollKey,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class SaferideCard extends StatelessWidget {
  const SaferideCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
