// "Who's watching?": the users signed in on this TV for the current server, plus Add user.
import 'package:flutter/material.dart';

import '../session.dart';
import '../theme.dart';
import '../ui/cards.dart';
import '../ui/tv.dart';

class UsersScreen extends StatelessWidget {
  final Session session;
  const UsersScreen({super.key, required this.session});

  static const _colors = [Color(0xFF7A4FB5), Color(0xFF2F7D6B), Color(0xFFB5604F), Color(0xFF4F6BB5), Color(0xFF9A7A2F), Color(0xFF8A3F6B)];

  @override
  Widget build(BuildContext context) {
    final server = session.current!;
    final client = session.client!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Back from here: the user who was watching, or the server list.
        if (didPop) return;
        if (server.signedIn) {
          session.switchTo(server.account!);
        } else {
          session.leaveServer();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text("Who's watching?", style: tv(64, weight: FontWeight.w700, spacing: -1)),
            const SizedBox(height: 14),
            Text(server.name, style: tv(24, color: Palette.text3)),
            const SizedBox(height: 70),
            FocusTraversalGroup(
              child: Wrap(spacing: 48, runSpacing: 40, alignment: WrapAlignment.center, children: [
                for (var i = 0; i < server.accounts.length; i++)
                  _tile(
                    label: server.accounts[i].userName,
                    color: _colors[i % _colors.length],
                    initial: server.accounts[i].userName.characters.firstOrNull?.toUpperCase() ?? '?',
                    image: server.accounts[i].imageTag == null ? null : client.userImage(server.accounts[i].userId, server.accounts[i].imageTag!),
                    autofocus: server.accounts[i].userId == server.currentUserId || (i == 0 && !server.signedIn),
                    onPressed: () => session.switchTo(server.accounts[i]),
                  ),
                _tile(label: 'Add user', color: Palette.surfaceRaised, icon: Icons.add, onPressed: session.addUser),
              ]),
            ),
            const SizedBox(height: 70),
            PillButton(label: 'Change server', height: 60, onPressed: session.leaveServer),
          ]),
        ),
      ),
    );
  }

  Widget _tile({required String label, required Color color, String? initial, String? image, IconData? icon, bool autofocus = false, required VoidCallback onPressed}) => TvFocusable(
        autofocus: autofocus,
        scale: 1.08,
        ensureVisible: false,
        onPressed: onPressed,
        builder: (context, focused) => SizedBox(
          width: 220,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 180,
              height: 180,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: focused ? focusShadow() : null),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: image != null
                  ? ClipOval(child: NetImage(image, cacheWidth: 360, fallback: Center(child: Text(initial ?? '', style: tv(76, weight: FontWeight.w700)))))
                  : icon != null
                      ? Icon(icon, size: 80, color: Colors.white)
                      : Text(initial ?? '', style: tv(76, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 18),
            Text(label, style: tv(28, weight: FontWeight.w600, color: focused ? Colors.white : Palette.text2), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}
