import 'package:flutter/material.dart';
import 'jobs/jobs_list_screen.dart';
import 'forms_builder/forms_list_screen.dart';
import 'votes/votes_list_screen.dart';

class FormsMainScreen extends StatefulWidget {
  const FormsMainScreen({Key? key}) : super(key: key);

  @override
  State<FormsMainScreen> createState() => _FormsMainScreenState();
}

class _FormsMainScreenState extends State<FormsMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMobile ? 'Forms' : 'Forms Management',
          style: TextStyle(fontSize: isMobile ? 18 : 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
          tabs: [
            Tab(
              icon: const Icon(Icons.work_outline),
              text: isMobile ? null : 'Jobs',
              iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
            ),
            Tab(
              icon: const Icon(Icons.description_outlined),
              text: isMobile ? null : 'Forms',
              iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
            ),
            Tab(
              icon: const Icon(Icons.how_to_vote_outlined),
              text: isMobile ? null : 'Votes',
              iconMargin: EdgeInsets.only(bottom: isMobile ? 0 : 4),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          JobsListScreen(),
          FormsListScreen(),
          VotesListScreen(),
        ],
      ),
    );
  }
}
