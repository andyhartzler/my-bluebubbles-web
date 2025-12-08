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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forms Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.work_outline),
              text: 'Jobs',
            ),
            Tab(
              icon: Icon(Icons.description_outlined),
              text: 'Forms',
            ),
            Tab(
              icon: Icon(Icons.how_to_vote_outlined),
              text: 'Votes',
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
