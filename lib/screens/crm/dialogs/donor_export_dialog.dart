import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import 'package:bluebubbles/models/crm/donation.dart';
import 'package:bluebubbles/models/crm/donor.dart';
import 'package:bluebubbles/models/crm/donor_export_config.dart';
import 'package:bluebubbles/services/crm/donor_export_service.dart';

/// Dialog for configuring and executing donation exports
class DonorExportDialog extends StatefulWidget {
  const DonorExportDialog({
    super.key,
    required this.donations,
    required this.donors,
  });

  final List<Donation> donations;
  final Map<String, Donor> donors;

  @override
  State<DonorExportDialog> createState() => _DonorExportDialogState();
}

class _DonorExportDialogState extends State<DonorExportDialog>
    with SingleTickerProviderStateMixin {
  static const _unityBlue = Color(0xFF273351);
  static const _momentumBlue = Color(0xFF32A6DE);

  late TabController _tabController;

  // Field selection state
  DonorExportFields _fields = const DonorExportFields();

  // Filter state
  DonorExportFilters _filters = const DonorExportFilters();

  // Selection state
  Set<String> _selectedDonationIds = {};
  bool _selectAll = true;

  // Export format
  ExportFormat _format = ExportFormat.pdf;

  // Loading state
  bool _exporting = false;

  // Controllers for filter inputs
  final _minAmountController = TextEditingController();
  final _maxAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDonationIds = widget.donations.map((d) => d.id).toSet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  List<Donation> get _filteredDonations {
    return widget.donations.where((d) {
      // Date filter
      if (_filters.startDate != null && d.donationDate != null) {
        if (d.donationDate!.isBefore(_filters.startDate!)) return false;
      }
      if (_filters.endDate != null && d.donationDate != null) {
        final endOfDay = DateTime(
          _filters.endDate!.year,
          _filters.endDate!.month,
          _filters.endDate!.day,
          23,
          59,
          59,
        );
        if (d.donationDate!.isAfter(endOfDay)) return false;
      }

      // Amount filter
      if (_filters.minAmount != null && d.amount != null) {
        if (d.amount! < _filters.minAmount!) return false;
      }
      if (_filters.maxAmount != null && d.amount != null) {
        if (d.amount! > _filters.maxAmount!) return false;
      }

      // Payment method filter
      if (_filters.paymentMethod != null) {
        if (d.paymentMethod?.toLowerCase() !=
            _filters.paymentMethod!.toLowerCase()) {
          return false;
        }
      }

      // Thank you sent filter
      if (_filters.thankYouSent != null) {
        if (d.hasThankYou != _filters.thankYouSent!) return false;
      }

      return true;
    }).toList();
  }

  List<Donation> get _selectedDonations {
    return _filteredDonations
        .where((d) => _selectedDonationIds.contains(d.id))
        .toList();
  }

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      _selectAll = selectAll;
      if (selectAll) {
        _selectedDonationIds = _filteredDonations.map((d) => d.id).toSet();
      } else {
        _selectedDonationIds.clear();
      }
    });
  }

  void _toggleDonation(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedDonationIds.add(id);
      } else {
        _selectedDonationIds.remove(id);
      }
      _selectAll = _selectedDonationIds.length == _filteredDonations.length;
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_filters.startDate ?? now.subtract(const Duration(days: 30)))
        : (_filters.endDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _unityBlue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _filters = _filters.copyWith(startDate: picked);
        } else {
          _filters = _filters.copyWith(endDate: picked);
        }
        // Update selection to only include filtered donations
        _selectedDonationIds = _filteredDonations
            .where((d) => _selectedDonationIds.contains(d.id))
            .map((d) => d.id)
            .toSet();
      });
    }
  }

  Future<void> _performExport() async {
    if (_selectedDonations.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No donations selected')));
      return;
    }

    setState(() => _exporting = true);

    try {
      // Build export rows with donor data
      final exportRows = _selectedDonations.map((donation) {
        final donor = widget.donors[donation.donorId];

        return DonationExportRow(
          donorName: donation.donorName ?? donor?.name ?? 'Unknown',
          email: donation.donorEmail ?? donor?.email,
          phone: donation.donorPhone ?? donor?.phone,
          address: donor?.address,
          city: donor?.city,
          state: donor?.state,
          zipCode: donor?.zipCode,
          employer: donor?.employer,
          occupation: donor?.occupation,
          county: donor?.county,
          congressionalDistrict: donor?.congressionalDistrict,
          amount: donation.amount,
          donationDate: donation.donationDate,
          paymentMethod: donation.paymentMethodLabel,
          checkNumber: donation.checkNumber,
          eventName: donation.eventName,
          notes: donation.notes,
          thankYouSent: donation.hasThankYou,
          isRecurring: donor?.isRecurringDonor ?? false,
        );
      }).toList();

      // Generate export
      final bytes = _format == ExportFormat.pdf
          ? await DonorExportService.generatePdf(
              donations: exportRows,
              fields: _fields,
              title: 'Donations Export',
              filterSummary: _filters.filterSummary,
            )
          : await DonorExportService.generateExcel(
              donations: exportRows,
              fields: _fields,
              title: 'Donations Export',
              filterSummary: _filters.filterSummary,
            );

      // Save file
      final extension = _format == ExportFormat.pdf ? 'pdf' : 'xlsx';
      final mimeType = _format == ExportFormat.pdf
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      final now = DateTime.now();
      final filename =
          'donations_export_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}${now.second}.$extension';

      // Web download using browser APIs
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export downloaded: $filename'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    } catch (e) {
      debugPrint('Export error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCount = _filteredDonations.length;
    final selectedCount = _selectedDonations.length;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _unityBlue,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.file_download_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Donations',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$selectedCount of $filteredCount donations selected',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                controller: _tabController,
                labelColor: _unityBlue,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: _momentumBlue,
                tabs: const [
                  Tab(icon: Icon(Icons.check_box_outlined), text: 'Fields'),
                  Tab(icon: Icon(Icons.filter_list), text: 'Filters'),
                  Tab(icon: Icon(Icons.checklist), text: 'Selection'),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildFieldsTab(theme),
                  _buildFiltersTab(theme),
                  _buildSelectionTab(theme),
                ],
              ),
            ),

            // Footer with format selection and export button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Format selector
                  SegmentedButton<ExportFormat>(
                    segments: const [
                      ButtonSegment(
                        value: ExportFormat.pdf,
                        label: Text('PDF'),
                        icon: Icon(Icons.picture_as_pdf, size: 18),
                      ),
                      ButtonSegment(
                        value: ExportFormat.xlsx,
                        label: Text('Excel'),
                        icon: Icon(Icons.table_chart, size: 18),
                      ),
                    ],
                    selected: {_format},
                    onSelectionChanged: (s) =>
                        setState(() => _format = s.first),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return _unityBlue;
                        }
                        return null;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return null;
                      }),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _exporting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _exporting || selectedCount == 0
                        ? null
                        : _performExport,
                    icon: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download),
                    label: Text(
                      _exporting ? 'Exporting...' : 'Export $selectedCount',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _unityBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsTab(ThemeData theme) {
    // Check if all fields are selected
    final allSelected = _fields.donorName &&
        _fields.email &&
        _fields.phone &&
        _fields.address &&
        _fields.city &&
        _fields.state &&
        _fields.zipCode &&
        _fields.employer &&
        _fields.occupation &&
        _fields.county &&
        _fields.congressionalDistrict &&
        _fields.amount &&
        _fields.donationDate &&
        _fields.paymentMethod &&
        _fields.checkNumber &&
        _fields.eventName &&
        _fields.notes &&
        _fields.thankYouSent &&
        _fields.isRecurring;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Select which fields to include in your export:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (allSelected) {
                      // Deselect all (keep only required fields)
                      _fields = const DonorExportFields(
                        donorName: true,
                        email: false,
                        phone: false,
                        address: false,
                        city: false,
                        state: false,
                        zipCode: false,
                        employer: false,
                        occupation: false,
                        county: false,
                        congressionalDistrict: false,
                        amount: true,
                        donationDate: true,
                        paymentMethod: false,
                        checkNumber: false,
                        eventName: false,
                        notes: false,
                        thankYouSent: false,
                        isRecurring: false,
                      );
                    } else {
                      // Select all
                      _fields = const DonorExportFields(
                        donorName: true,
                        email: true,
                        phone: true,
                        address: true,
                        city: true,
                        state: true,
                        zipCode: true,
                        employer: true,
                        occupation: true,
                        county: true,
                        congressionalDistrict: true,
                        amount: true,
                        donationDate: true,
                        paymentMethod: true,
                        checkNumber: true,
                        eventName: true,
                        notes: true,
                        thankYouSent: true,
                        isRecurring: true,
                      );
                    }
                  });
                },
                icon: Icon(
                  allSelected ? Icons.deselect : Icons.select_all,
                  size: 18,
                ),
                label: Text(allSelected ? 'Deselect All' : 'Select All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Contact Information
          _buildFieldSection(theme, 'Contact Information', [
            _FieldOption('Donor Name', _fields.donorName, (v) {
              setState(() => _fields = _fields.copyWith(donorName: v));
            }),
            _FieldOption('Email', _fields.email, (v) {
              setState(() => _fields = _fields.copyWith(email: v));
            }),
            _FieldOption('Phone', _fields.phone, (v) {
              setState(() => _fields = _fields.copyWith(phone: v));
            }),
          ]),

          // Address
          _buildFieldSection(theme, 'Address', [
            _FieldOption('Street Address', _fields.address, (v) {
              setState(() => _fields = _fields.copyWith(address: v));
            }),
            _FieldOption('City', _fields.city, (v) {
              setState(() => _fields = _fields.copyWith(city: v));
            }),
            _FieldOption('State', _fields.state, (v) {
              setState(() => _fields = _fields.copyWith(state: v));
            }),
            _FieldOption('ZIP Code', _fields.zipCode, (v) {
              setState(() => _fields = _fields.copyWith(zipCode: v));
            }),
          ]),

          // Employment
          _buildFieldSection(theme, 'Employment', [
            _FieldOption('Employer', _fields.employer, (v) {
              setState(() => _fields = _fields.copyWith(employer: v));
            }),
            _FieldOption('Occupation', _fields.occupation, (v) {
              setState(() => _fields = _fields.copyWith(occupation: v));
            }),
          ]),

          // Demographics
          _buildFieldSection(theme, 'Demographics', [
            _FieldOption('County', _fields.county, (v) {
              setState(() => _fields = _fields.copyWith(county: v));
            }),
            _FieldOption(
              'Congressional District',
              _fields.congressionalDistrict,
              (v) {
                setState(
                  () => _fields = _fields.copyWith(congressionalDistrict: v),
                );
              },
            ),
          ]),

          // Donation Details
          _buildFieldSection(theme, 'Donation Details', [
            _FieldOption('Amount', _fields.amount, (v) {
              setState(() => _fields = _fields.copyWith(amount: v));
            }),
            _FieldOption('Date', _fields.donationDate, (v) {
              setState(() => _fields = _fields.copyWith(donationDate: v));
            }),
            _FieldOption('Payment Method', _fields.paymentMethod, (v) {
              setState(() => _fields = _fields.copyWith(paymentMethod: v));
            }),
            _FieldOption('Check Number', _fields.checkNumber, (v) {
              setState(() => _fields = _fields.copyWith(checkNumber: v));
            }),
            _FieldOption('Event', _fields.eventName, (v) {
              setState(() => _fields = _fields.copyWith(eventName: v));
            }),
            _FieldOption('Notes', _fields.notes, (v) {
              setState(() => _fields = _fields.copyWith(notes: v));
            }),
            _FieldOption('Thank You Sent', _fields.thankYouSent, (v) {
              setState(() => _fields = _fields.copyWith(thankYouSent: v));
            }),
            _FieldOption('Recurring Donor', _fields.isRecurring, (v) {
              setState(() => _fields = _fields.copyWith(isRecurring: v));
            }),
          ]),
        ],
      ),
    );
  }

  Widget _buildFieldSection(
    ThemeData theme,
    String title,
    List<_FieldOption> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: _unityBlue,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: options.map((opt) {
            return SizedBox(
              width: 180,
              child: CheckboxListTile(
                value: opt.value,
                onChanged: (v) => opt.onChanged(v ?? false),
                title: Text(opt.label, style: const TextStyle(fontSize: 14)),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _momentumBlue,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFiltersTab(ThemeData theme) {
    final dateFormat = DateFormat.yMMMd();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter donations before exporting:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Date Range
          Text(
            'Date Range',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _unityBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _filters.startDate != null
                        ? dateFormat.format(_filters.startDate!)
                        : 'Start Date',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('to'),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _filters.endDate != null
                        ? dateFormat.format(_filters.endDate!)
                        : 'End Date',
                  ),
                ),
              ),
              if (_filters.startDate != null || _filters.endDate != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _filters = _filters.copyWith(
                        clearStartDate: true,
                        clearEndDate: true,
                      );
                    });
                  },
                  tooltip: 'Clear dates',
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Range
          Text(
            'Amount Range',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _unityBlue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Minimum',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final amount = double.tryParse(v);
                    setState(() {
                      if (amount != null) {
                        _filters = _filters.copyWith(minAmount: amount);
                      } else if (v.isEmpty) {
                        _filters = _filters.copyWith(clearMinAmount: true);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Maximum',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final amount = double.tryParse(v);
                    setState(() {
                      if (amount != null) {
                        _filters = _filters.copyWith(maxAmount: amount);
                      } else if (v.isEmpty) {
                        _filters = _filters.copyWith(clearMaxAmount: true);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Method
          Text(
            'Payment Method',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _unityBlue,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _filters.paymentMethod,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('All Methods')),
              DropdownMenuItem(value: 'actblue', child: Text('ActBlue')),
              DropdownMenuItem(value: 'check', child: Text('Check')),
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'venmo', child: Text('Venmo')),
              DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
              DropdownMenuItem(value: 'in-kind', child: Text('In-kind')),
            ],
            onChanged: (v) {
              setState(() {
                if (v == null) {
                  _filters = _filters.copyWith(clearPaymentMethod: true);
                } else {
                  _filters = _filters.copyWith(paymentMethod: v);
                }
              });
            },
          ),
          const SizedBox(height: 24),

          // Thank You Status
          Text(
            'Thank You Status',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: _unityBlue,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool?>(
            segments: const [
              ButtonSegment(value: null, label: Text('All')),
              ButtonSegment(value: true, label: Text('Thanked')),
              ButtonSegment(value: false, label: Text('Not Thanked')),
            ],
            selected: {_filters.thankYouSent},
            onSelectionChanged: (s) {
              setState(() {
                if (s.first == null) {
                  _filters = _filters.copyWith(clearThankYouSent: true);
                } else {
                  _filters = _filters.copyWith(thankYouSent: s.first);
                }
              });
            },
          ),
          const SizedBox(height: 24),

          // Filter Summary
          if (_filters.hasActiveFilters)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _momentumBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _momentumBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, color: _momentumBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filters.filterSummary,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filters = const DonorExportFilters();
                        _minAmountController.clear();
                        _maxAmountController.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectionTab(ThemeData theme) {
    final filtered = _filteredDonations;
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat.yMMMd();

    return Column(
      children: [
        // Select all bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _selectAll && filtered.isNotEmpty,
                onChanged: filtered.isEmpty
                    ? null
                    : (v) => _toggleSelectAll(v ?? false),
                activeColor: _momentumBlue,
              ),
              Text(
                '${_selectedDonations.length} of ${filtered.length} selected',
                style: theme.textTheme.bodyMedium,
              ),
              const Spacer(),
              TextButton(
                onPressed: filtered.isEmpty
                    ? null
                    : () => _toggleSelectAll(true),
                child: const Text('Select All'),
              ),
              TextButton(
                onPressed: _selectedDonationIds.isEmpty
                    ? null
                    : () => _toggleSelectAll(false),
                child: const Text('Deselect All'),
              ),
            ],
          ),
        ),

        // Donation list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_alt_off,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No donations match your filters',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _tabController.animateTo(1);
                        },
                        child: const Text('Adjust Filters'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final donation = filtered[index];
                    final isSelected = _selectedDonationIds.contains(
                      donation.id,
                    );

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) =>
                          _toggleDonation(donation.id, v ?? false),
                      activeColor: _momentumBlue,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              donation.donorName ?? 'Unknown Donor',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            donation.amount != null
                                ? currencyFormat.format(donation.amount)
                                : '-',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _unityBlue,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Text(
                            donation.donationDate != null
                                ? dateFormat.format(donation.donationDate!)
                                : 'No date',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _momentumBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              donation.paymentMethodLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _momentumBlue,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (donation.hasThankYou) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FieldOption {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  _FieldOption(this.label, this.value, this.onChanged);
}
