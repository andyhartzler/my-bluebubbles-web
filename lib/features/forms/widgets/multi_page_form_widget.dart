import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import '../models/form_field_config.dart';
import 'form_field_renderer.dart';
import 'conditional_field_wrapper.dart';

/// Multi-page form widget that splits fields across pages
class MultiPageFormWidget extends StatefulWidget {
  final List<FormFieldConfig> fields;
  final GlobalKey<FormBuilderState> formKey;
  final VoidCallback onSubmit;
  final bool showProgressIndicator;

  const MultiPageFormWidget({
    Key? key,
    required this.fields,
    required this.formKey,
    required this.onSubmit,
    this.showProgressIndicator = true,
  }) : super(key: key);

  @override
  State<MultiPageFormWidget> createState() => _MultiPageFormWidgetState();
}

class _MultiPageFormWidgetState extends State<MultiPageFormWidget> {
  int _currentPage = 0;
  late List<List<FormFieldConfig>> _pages;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _organizeFieldsIntoPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _organizeFieldsIntoPages() {
    // Group fields by page number
    final Map<int, List<FormFieldConfig>> pageMap = {};

    for (final field in widget.fields) {
      final pageNum = field.pageNumber ?? 0;
      pageMap.putIfAbsent(pageNum, () => []);
      pageMap[pageNum]!.add(field);
    }

    // Convert to sorted list of pages
    final sortedKeys = pageMap.keys.toList()..sort();
    _pages = sortedKeys.map((key) => pageMap[key]!).toList();

    // If only one page, it means fields don't use pageNumber property
    if (_pages.length <= 1 && widget.fields.isNotEmpty) {
      // Put all fields on one page
      _pages = [widget.fields];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return const Center(
        child: Text('No fields to display'),
      );
    }

    // Single page - render normally without pagination
    if (_pages.length == 1) {
      return SingleChildScrollView(
        child: Column(
          children: widget.fields.map((field) {
            return ConditionalFieldWrapper(
              config: field,
              formKey: widget.formKey,
              child: FormFieldRenderer(
                key: ValueKey(field.id),
                config: field,
                formKey: widget.formKey,
              ),
            );
          }).toList(),
        ),
      );
    }

    // Multi-page form
    return Column(
      children: [
        // Progress indicator
        if (widget.showProgressIndicator) _buildProgressIndicator(),

        // Page content
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable swipe
            itemCount: _pages.length,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
            itemBuilder: (context, pageIndex) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page title
                    Text(
                      'Page ${pageIndex + 1} of ${_pages.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    // Fields for this page
                    ..._pages[pageIndex].map((field) {
                      return ConditionalFieldWrapper(
                        config: field,
                        formKey: widget.formKey,
                        child: FormFieldRenderer(
                          key: ValueKey(field.id),
                          config: field,
                          formKey: widget.formKey,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ),

        // Navigation buttons
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_currentPage + 1) / _pages.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          // Page counter
          Text(
            'Step ${_currentPage + 1} of ${_pages.length}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousPage,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Previous'),
              ),
            )
          else
            const Spacer(),

          const SizedBox(width: 16),

          // Next/Submit button
          Expanded(
            child: _currentPage < _pages.length - 1
                ? ElevatedButton.icon(
                    onPressed: _nextPage,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                  )
                : ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.check),
                    label: const Text('Submit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextPage() {
    // Validate current page before moving to next
    if (_validateCurrentPage()) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentPage() {
    final formState = widget.formKey.currentState;
    if (formState == null) return false;

    // Get fields on current page
    final currentPageFields = _pages[_currentPage];
    bool isValid = true;

    // Validate each field on this page
    for (final field in currentPageFields) {
      final fieldState = formState.fields[field.id];
      if (fieldState != null) {
        if (!fieldState.validate()) {
          isValid = false;
        }
      }
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors on this page'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return isValid;
  }

  void _submitForm() {
    // Validate entire form
    if (widget.formKey.currentState?.saveAndValidate() ?? false) {
      widget.onSubmit();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix all errors in the form'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
