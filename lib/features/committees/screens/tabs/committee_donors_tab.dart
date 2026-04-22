import 'package:flutter/material.dart';

import 'package:bluebubbles/screens/crm/donor_command_center.dart';

/// Donors tab for the Fundraising committee workspace.
///
/// Embeds the canonical DonorCommandCenter in embed mode so the committee
/// workspace gets the full donors UI (MOYD Donors / Fundraising / Donor
/// Research / Call Time / Committees) without duplicating tab scaffolding.
class CommitteeDonorsTab extends StatelessWidget {
  const CommitteeDonorsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const DonorCommandCenter(embed: true);
  }
}
