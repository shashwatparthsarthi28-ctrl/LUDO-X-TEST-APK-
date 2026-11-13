import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/theme.dart';
import '../services/models.dart';
import 'admin_screen.dart';
import 'calculator_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<MatchRecord> _history = [];

  @override
  void initState() {
    super.initState();
    app.addListener(_r);
    _load();
  }

  @override
  void dispose() {
    app.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await app.refresh();
    try {
      final h = await app.backend.getHistory();
      if (mounted) setState(() => _history = h);
    } catch (_) {}
  }

  Future<void> _edit() async {
    final p = app.profile!;
    final name = TextEditingController(text: p.username);
    var avatar = p.avatar;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, maxLength: 16, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text('Avatar', style: Gx.label())),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < kAvatarCount; i++)
                  GestureDetector(
                    onTap: () => set(() => avatar = i),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: avatar == i ? Gx.goldLight : Colors.transparent, width: 2.5)),
                      child: AvatarView(index: i, size: 44, ring: false),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Gx.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save', style: TextStyle(color: Gx.gold, fontWeight: FontWeight.w800))),
          ],
        );
      }),
    );
    if (ok != true) return;
    try {
      await app.backend.updateProfile(name.text, avatar);
      await app.refresh();
      if (mounted) toast(context, 'Profile updated');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your demo wallet and history stay saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(color: Gx.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sign out', style: TextStyle(color: Gx.bad))),
        ],
      ),
    );
    if (ok == true) await app.signOut();
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    if (p == null) return const SizedBox();
    return RefreshIndicator(
      color: Gx.gold,
      backgroundColor: Gx.card,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Center(
          child: Column(children: [
            const SizedBox(height: 8),
            AvatarView(index: p.avatar, size: 96),
            const SizedBox(height: 12),
            Text(p.username, style: Gx.display(24)),
            const SizedBox(height: 4),
            Text(p.isGuest ? 'Guest account' : (p.email.isEmpty ? '' : p.email), style: Gx.label(size: 12)),
            const SizedBox(height: 12),
            GoldButton(label: 'EDIT PROFILE', icon: Icons.edit, outlined: true, compact: true, onPressed: _edit),
          ]),
        ),
        const SectionHeader('Statistics'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            StatTile(label: 'Games played', value: '${p.played}', icon: Icons.sports_esports),
            StatTile(label: 'Wins', value: '${p.wins}', icon: Icons.emoji_events, valueColor: Gx.goldLight),
            StatTile(label: 'Losses', value: '${p.losses}', icon: Icons.heart_broken),
            StatTile(label: 'Win rate', value: pct(p.winRate), icon: Icons.percent),
          ],
        ),
        const SizedBox(height: 10),
        StatTile(label: 'Total simulated earnings (net)', value: inr(p.earnings, sign: true), icon: Icons.savings, valueColor: p.earnings >= 0 ? Gx.good : Gx.bad),
        const SizedBox(height: 6),
        Text('Stats count paid demo matches only; Practice is excluded.', style: Gx.label(size: 11)),
        SectionHeader('Match history', action: _history.isEmpty ? null : 'See all', onAction: () => _push(const HistoryScreen())),
        if (_history.isEmpty)
          AppCard(child: Text('No matches yet.', style: Gx.label(size: 13)))
        else
          for (final m in _history.take(5)) MatchTile(record: m),
        const SectionHeader('More'),
        _item(Icons.notifications_none, 'Notifications', app.unread > 0 ? '${app.unread} new' : null, () => _push(const NotificationsScreen())),
        _item(Icons.calculate, 'Payout calculator', null, () => _push(const CalculatorScreen())),
        if (p.isAdmin) _item(Icons.admin_panel_settings, 'Admin dashboard', null, () => _push(const AdminScreen())),
        _item(app.soundOn ? Icons.volume_up : Icons.volume_off, app.soundOn ? 'Sound: on' : 'Sound: off', null, app.toggleSound),
        _item(Icons.shield_outlined, 'Fair play & security', null, () => _push(const FairPlayScreen())),
        _item(Icons.logout, 'Sign out', null, _signOut, danger: true),
        const SizedBox(height: 10),
        Text('Backend: ${app.backend.label}', style: Gx.label(size: 11), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _item(IconData i, String t, String? trailing, VoidCallback f, {bool danger = false}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: f,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(i, color: danger ? Gx.bad : Gx.gold, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(t, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? Gx.bad : Gx.text))),
            if (trailing != null) MiniTag(trailing),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Gx.muted),
          ]),
        ),
      );
}

/// Plain-language summary of the security model, as required for the prototype.
class FairPlayScreen extends StatelessWidget {
  const FairPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String b) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, color: Gx.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(b, style: const TextStyle(color: Gx.muted, fontSize: 13, height: 1.35)),
                ]),
              ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('FAIR PLAY & SECURITY')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const SimBanner(),
        const SizedBox(height: 14),
        item(Icons.casino, 'Server-authoritative dice', 'Dice are derived on the server from a secret seed. The app only sends "roll" and shows the result. Before roll #1 the server publishes sha256(seed); after the match it reveals the seed so you can verify every roll.'),
        item(Icons.lock, 'Secure match state', 'Match state, balances and ledgers cannot be written by the app. Firestore rules are read-only for clients and every change goes through Cloud Functions.'),
        item(Icons.account_balance_wallet, 'No client-side balance changes', 'Entry fees and rewards are applied by the server in one transaction when a match starts and ends.'),
        item(Icons.receipt_long, 'Match logs', 'Every roll, move, capture, skip and timeout is stored in a hash-chained log. Open it from the match screen or your history.'),
        item(Icons.gpp_good, 'Anti-cheat validation', 'The server rejects stale or replayed requests, out-of-turn actions, illegal tokens, too-fast actions and early timeouts, logs each violation and flags repeat offenders.'),
        item(Icons.smart_toy, 'Bots are always labelled', 'Every AI opponent shows an AI BOT tag with its difficulty and strategy. You are never matched with hidden bots and every opponent in this prototype is a bot.'),
        item(Icons.science, 'Simulated money only', 'No real deposit, withdrawal or prize exists in this app. Real payments are disabled until legal and regulatory requirements are independently verified.'),
      ]),
    );
  }
}
