import 'package:flutter/material.dart';
import '../../models/form_schema.dart';
import '../../services/forms_service.dart';
import '../../widgets/form_card.dart';
import 'form_builder_screen.dart';

class FormsListScreen extends StatefulWidget {
  const FormsListScreen({Key? key}) : super(key: key);

  @override
  State<FormsListScreen> createState() => _FormsListScreenState();
}

class _FormsListScreenState extends State<FormsListScreen>
    with AutomaticKeepAliveClientMixin {
  final _formsService = FormsService();
  String _typeFilter = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Survey', 'survey'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Registration', 'registration'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Feedback', 'feedback'),
                ],
              ),
            ),
          ),

          // Forms List
          Expanded(
            child: StreamBuilder<List<FormSchema>>(
              stream: _formsService.watchForms(_typeFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final forms = snapshot.data ?? [];

                if (forms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No forms yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _createNewForm,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Form'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: forms.length,
                    itemBuilder: (context, index) {
                      final form = forms[index];
                      return FormCard(
                        form: form,
                        onTap: () => _editForm(form),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewForm,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _typeFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _typeFilter = value;
        });
      },
    );
  }

  void _createNewForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FormBuilderScreen(),
      ),
    );
  }

  void _editForm(FormSchema form) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormBuilderScreen(formId: form.id),
      ),
    );
  }
}
