import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/payout.dart';
import '../core/theme.dart';
import '../services/models.dart';
import '../widgets/dialogs.dart';
import 'calculator_screen.dart';
import 'game_screen.dart';
import 'history_screen.dart';
import 'mode_screens.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) goTo;
  const HomeScreen({super.key, required this.goTo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MatchRecord> _history = [];
  List<LeaderEntry> _leaders = [];
  bool _loading = true;

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
      final l = await app.backend.getLeaderboard();
      if (mounted) setState(() {
        _history = h;
        _leaders = l;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deposit() async {
    final amt = await askAmount(context,
        title: 'Add demo funds',
        hint: 'Amount (demo)',
        confirm: 'ADD',
        quick: const [100, 500, 1000, 5000],
        max: app.config.maxDemoDeposit);
    if (amt == null) return;
    try {
      await app.backend.demoDeposit(amt);
      await _load();
      if (mounted) toast(context, 'Added ${inr(amt)} demo funds (simulated)');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _withdraw() async {
    final amt = await askAmount(context,
        title: 'Request demo withdrawal', hint: 'Amount (demo)', confirm: 'REQUEST', quick: const [100, 500], max: app.balance);
    if (amt == null) return;
    try {
      await app.backend.requestWithdrawal(amt);
      await _load();
      if (mounted) toast(context, 'Simulated withdrawal requested. No real payout is made.');
    } on BackendException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  Future<void> _play(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = app.profile;
    if (p == null) return const SizedBox();
    return RefreshIndicator(
      color: Gx.gold,
      backgroundColor: Gx.card,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // header
          Row(children: [
            GestureDetector(onTap: () => widget.goTo(3), child: AvatarView(index: p.avatar, size: 54)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WELCOME BACK', style: Gx.label(size: 10.5)),
                Text(p.username, style: Gx.display(20), overflow: TextOverflow.ellipsis),
              ]),
            ),
            IconButton(
              tooltip: app.soundOn ? 'Mute sound' : 'Unmute sound',
              onPressed: app.toggleSound,
              icon: Icon(app.soundOn ? Icons.volume_up : Icons.volume_off, color: Gx.muted),
            ),
            Stack(children: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  await app.refresh();
                },
                icon: const Icon(Icons.notifications_none, color: Gx.gold, size: 28),
              ),
              if (app.unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: Gx.bad, borderRadius: BorderRadius.circular(9)),
                    child: Text('${app.unread}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
            ]),
          ]),
          const SizedBox(height: 14),
          // wallet card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [Color(0xFF2A2108), Color(0xFF0E0E0E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Gx.gold.withOpacity(0.6)),
              boxShadow: [BoxShadow(color: Gx.gold.withOpacity(0.18), blurRadius: 26)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('DEMO WALLET', style: Gx.label(color: Gx.goldLight)),
                const SizedBox(width: 8),
                const MiniTag('SIMULATED'),
              ]),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(end: app.balance),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => ShaderMask(
                  shaderCallback: (r) => Gx.goldGradient.createShader(r),
                  child: Text(inr(v), style: Gx.display(40, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: GoldButton(label: 'DEPOSIT', icon: Icons.add_circle_outline, compact: true, onPressed: _deposit)),
                const SizedBox(width: 10),
                Expanded(child: GoldButton(label: 'WITHDRAW', icon: Icons.arrow_circle_up_outlined, outlined: true, compact: true, onPressed: _withdraw)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
          const SimBanner(compact: true),
          // game modes
          const SectionHeader('Game modes'),
          _ModeCard(
            icon: Icons.school,
            title: 'PRACTICE',
            tag: 'FREE',
            lines: const ['Play against 3 AI bots', 'No wallet deductions, no rewards', 'Unlimited practice'],
            onTap: () => _play(const GameScreen(mode: 'practice')),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.emoji_events,
            title: 'COMPETITIVE DEMO',
            tag: '${inr(app.config.competitiveEntry)} ENTRY',
            lines: [
              '4 players: you + 3 AI bots',
              'Pool ${inr(PayoutConfig(entry: app.config.competitiveEntry, multipliers: app.config.multipliers).pool)}  |  1st ${inr(PayoutConfig(entry: app.config.competitiveEntry, multipliers: app.config.multipliers).payouts[0])}',
              'See the full payout breakdown first',
            ],
            hot: true,
            onTap: () => _play(const CompetitiveScreen()),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.smart_toy,
            title: 'PRO BOT CHALLENGE',
            tag: '${app.config.proTiers.map((e) => inr(e)).join(' / ')}',
            lines: const ['Choose Easy, Medium or Hard bots', 'Pick your demo entry tier', 'Simulated winnings only'],
            onTap: () => _play(const ProBotScreen()),
          ),
          // tools
          const SectionHeader('Tools'),
          Row(children: [
            Expanded(
              child: AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalculatorScreen())),
                child: const Column(children: [Icon(Icons.calculate, color: Gx.gold, size: 28), SizedBox(height: 6), Text('Payout calculator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
                child: const Column(children: [Icon(Icons.history, color: Gx.gold, size: 28), SizedBox(height: 6), Text('Match history', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
              ),
            ),
          ]),
          // history preview
          SectionHeader('Recent matches', action: _history.isEmpty ? null : 'See all', onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen()))),
          if (_loading)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Gx.gold)))
          else if (_history.isEmpty)
            AppCard(child: Row(children: [
              const Icon(Icons.sports_esports, color: Gx.muted),
              const SizedBox(width: 12),
              Expanded(child: Text('No matches yet. Start with a free Practice game.', style: Gx.label(size: 13))),
            ]))
          else
            for (final m in _history.take(3)) MatchTile(record: m),
          // leaderboard preview
          SectionHeader('Leaderboard', action: 'View all', onAction: () => widget.goTo(2)),
          for (var i = 0; i < _leaders.length && i < 3; i++)
            LeaderTile(rank: i + 1, entry: _leaders[i], me: _leaders[i].uid == p.uid),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String tag;
  final List<String> lines;
  final VoidCallback onTap;
  final bool hot;
  const _ModeCard({required this.icon, required this.title, required this.tag, required this.lines, required this.onTap, this.hot = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glow: hot,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(gradient: Gx.goldGradient, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: Colors.black, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title, style: Gx.display(15), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Flexible(child: MiniTag(tag)),
            ]),
            const SizedBox(height: 6),
            for (final l in lines) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l, style: Gx.label(size: 12))),
          ]),
        ),
        const Icon(Icons.chevron_right, color: Gx.gold),
      ]),
    );
  }
}

class MatchTile extends StatelessWidget {
  final MatchRecord record;
  const MatchTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final win = record.rank == 1;
    final paid = record.entry > 0;
    final net = record.net;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (win ? Gx.gold : Gx.cardHi),
            ),
            child: Text(ordinal(record.rank), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: win ? Colors.black : Gx.text)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(modeTitle(record.mode), style: const TextStyle(fontWeight: FontWeight.w800)),
              Text('${timeAgo(record.ts)}${record.completed ? '' : '  |  abandoned'}${record.difficulty.isNotEmpty && record.difficulty != '-' ? '  |  ${record.difficulty}' : ''}',
                  style: Gx.label(size: 11), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text(paid ? inr(net, sign: true) : 'Free',
              style: TextStyle(fontWeight: FontWeight.w900, color: !paid ? Gx.muted : (net >= 0 ? Gx.good : Gx.bad))),
        ]),
      ),
    );
  }
}

class LeaderTile extends StatelessWidget {
  final int rank;
  final LeaderEntry entry;
  final bool me;
  const LeaderTile({super.key, required this.rank, required this.entry, this.me = false});

  @override
  Widget build(BuildContext context) {
    const medals = [Color(0xFFFFD54F), Color(0xFFCFD8DC), Color(0xFFCD7F32)];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        glow: me,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: rank <= 3 ? Icon(Icons.workspace_premium, color: medals[rank - 1]) : Text('$rank', style: const TextStyle(fontWeight: FontWeight.w900, color: Gx.muted)),
          ),
          AvatarView(index: entry.avatar, size: 38, ring: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                if (me) ...[const SizedBox(width: 6), const MiniTag('YOU')],
                if (entry.sample) ...[const SizedBox(width: 6), const MiniTag('SAMPLE', color: Gx.muted)],
              ]),
              Text('${entry.wins} wins', style: Gx.label(size: 11)),
            ]),
          ),
          Text(inr(entry.earnings, sign: true), style: TextStyle(fontWeight: FontWeight.w900, color: entry.earnings >= 0 ? Gx.goldLight : Gx.bad)),
        ]),
      ),
    );
  }
}
