// Mockup 11 · Settings, only what a TV viewer changes: playback, subtitles, account, versions.
// Categories on the left; each row shows its value and OK opens a side panel of choices.
// Language preferences are the user's on the server; the rest is kept on this TV.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/panel.dart';
import '../ui/subtitle_text.dart';
import '../ui/tv.dart';

class SettingsScreen extends StatefulWidget {
  final Session session;
  const SettingsScreen({super.key, required this.session});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _Cat { playback, subtitles, account, about }

class _SettingsScreenState extends State<SettingsScreen> {
  _Cat _cat = _Cat.playback;
  Map<String, dynamic>? _config;
  String? _serverVersion;

  Session get _s => widget.session;
  JellyfinClient get _client => _s.client!;

  @override
  void initState() {
    super.initState();
    _client.userConfiguration().then((c) {
      if (mounted) setState(() => _config = c);
    }).catchError((_) {});
    _client.publicInfo().then((i) {
      if (mounted) setState(() => _serverVersion = i.version);
    }).catchError((_) {});
  }

  Future<void> _saveConfig(String key, Object? value) async {
    final c = {...?_config, key: value};
    setState(() => _config = c);
    try {
      await _client.saveUserConfiguration(c);
    } on ApiException catch (_) {}
  }

  Future<T?> _choose<T>(String title, List<(String, T)> options, T current) => showSidePanel<T>(
        context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(48, 80, 48, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PanelHeader(title: title),
            Expanded(
              child: ListView(children: [
                for (final (label, value) in options)
                  PanelRow(title: label, selected: value == current, autofocus: value == current, onPressed: () => Navigator.of(context).pop(value)),
              ]),
            ),
          ]),
        ),
      );

  static const _bitrates = [
    ('Auto (up to 120 Mbps)', 120000000),
    ('60 Mbps · 4K', 60000000),
    ('40 Mbps · 4K', 40000000),
    ('20 Mbps · 1080p', 20000000),
    ('10 Mbps · 1080p', 10000000),
    ('4 Mbps · 720p', 4000000),
  ];

  static const _languages = [
    ('Any (as in the file)', ''),
    ('English', 'eng'), ('Hindi', 'hin'), ('Nepali', 'nep'), ('Spanish', 'spa'), ('French', 'fre'), ('German', 'ger'),
    ('Japanese', 'jpn'), ('Korean', 'kor'), ('Tamil', 'tam'), ('Telugu', 'tel'),
  ];

  static const _subtitleModes = [
    ('As the file says', 'Default'),
    ('Only forced subtitles', 'OnlyForced'),
    ('Always on', 'Always'),
    ('When the audio is in another language', 'Smart'),
    ('Off', 'None'),
  ];

  static const _skipModes = [('Show a Skip button', 'button'), ('Skip automatically', 'auto'), ('Off', 'off')];
  static const _subSizes = [('Small', 34), ('Medium', 44), ('Large', 56), ('Extra large', 70)];
  static const _subColors = [('White', 'white'), ('Yellow', 'yellow')];
  static const _subBackgrounds = [('Drop shadow', 'shadow'), ('Outline', 'outline'), ('Translucent box', 'box'), ('Black box', 'solid')];
  static const _subLifts = [('Low', 40), ('Normal', 90), ('Raised', 170)];

  @override
  Widget build(BuildContext context) {
    final cur = _s.current!;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: 560,
          padding: const EdgeInsets.fromLTRB(40, 56, 40, 40),
          decoration: const BoxDecoration(color: Color(0xFF12151D), border: Border(right: BorderSide(color: Color(0x0FFFFFFF)))),
          child: FocusTraversalGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                PillButton(icon: Icons.arrow_back_ios_new, tooltip: 'Back', height: 60, onPressed: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 18),
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xFF7A4FB5), shape: BoxShape.circle),
                  child: Text((cur.userName ?? '?').characters.first.toUpperCase(), style: tv(36, weight: FontWeight.w700)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cur.userName ?? '', style: tv(32, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(cur.name, style: tv(20, color: Palette.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
              const SizedBox(height: 34),
              for (final (c, label) in [(_Cat.playback, 'Playback'), (_Cat.subtitles, 'Subtitles'), (_Cat.account, 'Account'), (_Cat.about, 'About')])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TvFocusable(
                    autofocus: c == _cat,
                    ensureVisible: false,
                    onPressed: () => setState(() => _cat = c),
                    onFocus: (f) {
                      if (f) setState(() => _cat = c);
                    },
                    builder: (context, focused) => AnimatedContainer(
                      duration: const Duration(milliseconds: 110),
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(color: focused ? Colors.white : (_cat == c ? Palette.surfaceRaised : null), borderRadius: BorderRadius.circular(14)),
                      child: Text(label, style: tv(25, weight: FontWeight.w600, color: focused ? Palette.ground : (_cat == c ? Colors.white : const Color(0xBFFFFFFF)))),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        Expanded(
          child: FocusTraversalGroup(
            child: ListView(padding: const EdgeInsets.fromLTRB(90, 76, 110, 60), children: [
              Text(switch (_cat) { _Cat.playback => 'Playback', _Cat.subtitles => 'Subtitles', _Cat.account => 'Account', _Cat.about => 'About' }, style: tv(48, weight: FontWeight.w700)),
              const SizedBox(height: 26),
              ...switch (_cat) {
                _Cat.playback => _playback(),
                _Cat.subtitles => _subtitles(),
                _Cat.account => _account(),
                _Cat.about => _about(),
              },
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(String title, String help, String value, VoidCallback? onPressed, {bool danger = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TvFocusable(
          onPressed: onPressed,
          builder: (context, focused) => AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 18),
            decoration: BoxDecoration(color: focused ? Palette.surfaceRaised : Palette.surface, borderRadius: BorderRadius.circular(16), boxShadow: focused ? focusShadow(ring: 3) : null),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tv(26, weight: FontWeight.w600, color: danger ? Palette.danger : Colors.white)),
                  if (help.isNotEmpty) ...[const SizedBox(height: 6), Text(help, style: tv(20, color: Palette.text3))],
                ]),
              ),
              if (value.isNotEmpty) Text(value, style: tv(24, weight: FontWeight.w600, color: Palette.accentText)),
              if (onPressed != null) ...[const SizedBox(width: 14), const Icon(Icons.chevron_right, color: Palette.text3, size: 26)],
            ]),
          ),
        ),
      );

  List<Widget> _playback() {
    final br = _bitrates.where((b) => b.$2 == _s.maxBitrate).firstOrNull?.$1 ?? '${_s.maxBitrate ~/ 1000000} Mbps';
    final audioLang = (_config?['AudioLanguagePreference'] as String?) ?? '';
    return [
      _row('Maximum streaming quality', 'Lower it if playback stalls on a slow network', br, () async {
        final v = await _choose('Maximum streaming quality', _bitrates, _s.maxBitrate);
        if (v != null) await _s.setInt('maxBitrate', v);
        setState(() {});
      }),
      _row('Preferred audio language', 'Chosen first when a title has several', audioLang.isEmpty ? 'Any' : (languageName(audioLang) ?? audioLang), () async {
        final v = await _choose('Preferred audio language', _languages, audioLang);
        if (v != null) await _saveConfig('AudioLanguagePreference', v.isEmpty ? null : v);
      }),
      _row('Play the next episode automatically', 'When an episode ends', _s.autoplayNext ? 'On' : 'Off', () async {
        final v = await _choose('Play the next episode automatically', const [('On', true), ('Off', false)], _s.autoplayNext);
        if (v != null) await _s.setBool('autoplayNext', v);
        setState(() {});
      }),
      _row('Skip intros and recaps', 'Uses the intro markers on your server', _skipModes.where((m) => m.$2 == _s.skipSegments).firstOrNull?.$1 ?? '', () async {
        final v = await _choose('Skip intros and recaps', _skipModes, _s.skipSegments);
        if (v != null) await _s.setString('skipSegments', v);
        setState(() {});
      }),
      _row('Seek step', 'Left and right on the remote while playing', '${_s.seekBack} s back · ${_s.seekForward} s ahead', () async {
        final v = await _choose('Seek step', const [('5 s back · 10 s ahead', (5, 10)), ('10 s back · 30 s ahead', (10, 30)), ('15 s back · 60 s ahead', (15, 60))], (_s.seekBack, _s.seekForward));
        if (v != null) {
          await _s.setInt('seekBack', v.$1);
          await _s.setInt('seekForward', v.$2);
        }
        setState(() {});
      }),
    ];
  }

  List<Widget> _subtitles() {
    final lang = (_config?['SubtitleLanguagePreference'] as String?) ?? '';
    final mode = (_config?['SubtitleMode'] as String?) ?? 'Default';
    return [
      _row('Subtitle language', 'Chosen first when a title has several', lang.isEmpty ? 'Any' : (languageName(lang) ?? lang), () async {
        final v = await _choose('Subtitle language', _languages, lang);
        if (v != null) await _saveConfig('SubtitleLanguagePreference', v.isEmpty ? null : v);
      }),
      _row('When to show subtitles', '', _subtitleModes.where((m) => m.$2 == mode).firstOrNull?.$1 ?? mode, () async {
        final v = await _choose('When to show subtitles', _subtitleModes, mode);
        if (v != null) await _saveConfig('SubtitleMode', v);
      }),
      const SizedBox(height: 14),
      _subtitlePreview(),
      const SizedBox(height: 26),
      _pick('Text size', _subSizes, _s.subSize, 'subSize'),
      _pick('Text colour', _subColors, _s.subColor, 'subColor'),
      _pick('Background', _subBackgrounds, _s.subBackground, 'subBackground'),
      _pick('Position', _subLifts, _s.subLift, 'subLift'),
    ];
  }

  Widget _pick<T>(String title, List<(String, T)> options, T current, String key) =>
      _row(title, '', options.where((o) => o.$2 == current).firstOrNull?.$1 ?? '$current', () async {
        final v = await _choose(title, options, current);
        if (v is int) await _s.setInt(key, v);
        if (v is String) await _s.setString(key, v);
        setState(() {});
      });

  /// A still frame with the caption as the player will draw it (a 1920×1080 stage, scaled down).
  Widget _subtitlePreview() => Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 620,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: FittedBox(
                child: SizedBox(
                  width: 1920,
                  height: 1080,
                  child: Stack(children: [
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3A5A78), Color(0xFFB98A5A), Color(0xFFE8D8B0)]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 200,
                      right: 200,
                      bottom: _s.subLift.toDouble(),
                      child: Center(child: SubtitleText('This is how subtitles will look.', session: _s)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  List<Widget> _account() => [
        _row('Switch user', '${_s.current!.accounts.length} signed in on this TV', '', () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          _s.chooseUser();
        }),
        _row('Add user', 'Sign in another user; both stay signed in', '', () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          _s.addUser();
        }),
        _row('Change server', 'Back to the server list; you stay signed in here', '', () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          _s.leaveServer();
        }),
        _row('Sign out', 'Remove ${_s.current!.userName ?? 'this user'} from this TV', '', () async {
          final ok = await confirmPanel(context, title: 'Sign out?', detail: 'You will need Quick Connect or your password to sign in again.', confirm: 'Sign out');
          if (!ok || !mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          _s.signOut();
        }, danger: true),
      ];

  List<Widget> _about() => [
        _row('App version', '', appVersion, null),
        _row('Server', _s.current!.url, _serverVersion == null ? '' : 'Jellyfin $_serverVersion', null),
      ];
}
