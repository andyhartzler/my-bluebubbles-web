import 'package:flutter/material.dart';

import 'package:bluebubbles/screens/crm/donors_list_screen.dart';

/// Donors tab for the Fundraising committee
/// Embeds the full DonorsListScreen
class CommitteeDonorsTab extends StatelessWidget {
  const CommitteeDonorsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Embed the full donors screen with embed mode
    return const DonorsListScreen(embed: true);
  }
}
