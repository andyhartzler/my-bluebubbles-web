import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/features/mail/providers/mail_inbox_provider.dart';
import 'package:bluebubbles/features/mail/screens/mail_inbox_view.dart';

/// Root mail screen — wraps the inbox in a brand-themed scaffold so it
/// shares the rest of the CRM's navy/gradient look. Phase 1 has only
/// the inbox; Phase 2 will add the composer screen here.
class MailScreen extends StatelessWidget {
  const MailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MailInboxProvider()..refresh(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BrandedBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  _MailHeader(),
                  SizedBox(height: 12),
                  Expanded(child: MailInboxView()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MailHeader extends StatelessWidget {
  const _MailHeader();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: BrandColors.getTileGradient(),
          boxShadow: [
            BoxShadow(
              color: BrandColors.unityBlue.withOpacity(0.32),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mail_outline, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Mail',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _RefreshButton(),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<MailInboxProvider>(
      builder: (_, inbox, __) => IconButton(
        tooltip: 'Refresh inbox',
        onPressed: inbox.loading ? null : inbox.refresh,
        icon: inbox.loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}
