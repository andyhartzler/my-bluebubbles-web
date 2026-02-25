import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/tabs/fundraising_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/mec_research_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/call_time_tab.dart';
import 'package:bluebubbles/screens/crm/tabs/committees_tab.dart';

class DonorsListScreen extends StatefulWidget {
  final bool embed;

  const DonorsListScreen({super.key, this.embed = false});

  @override
  State<DonorsListScreen> createState() => _DonorsListScreenState();
}

class _DonorsListScreenState extends State<DonorsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.volunteer_activism), text: 'Fundraising'),
                Tab(icon: Icon(Icons.search), text: 'Donor Research'),
                Tab(icon: Icon(Icons.phone_callback), text: 'Call Time'),
                Tab(icon: Icon(Icons.account_balance), text: 'Committees'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: BrandColors.sunriseGold,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Expanded(
          child: BrandedBackground(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                FundraisingTab(),
                MecResearchTab(),
                CallTimeTab(),
                CommitteesTab(),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embed) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donors & Research',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: BrandColors.tileGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: content,
    );
  }
}
