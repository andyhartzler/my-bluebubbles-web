/// Configuration models for donor/donation export functionality.

/// Export format options
enum ExportFormat { pdf, xlsx }

/// Defines which fields to include in the export
class DonorExportFields {
  // Donor contact info
  final bool donorName;
  final bool email;
  final bool phone;

  // Donor address
  final bool address;
  final bool city;
  final bool state;
  final bool zipCode;

  // Donor employment
  final bool employer;
  final bool occupation;

  // Donor demographics
  final bool county;
  final bool congressionalDistrict;

  // Donation details
  final bool amount;
  final bool donationDate;
  final bool paymentMethod;
  final bool checkNumber;
  final bool eventName;
  final bool notes;
  final bool thankYouSent;
  final bool isRecurring;

  const DonorExportFields({
    this.donorName = true,
    this.email = true,
    this.phone = false,
    this.address = false,
    this.city = false,
    this.state = false,
    this.zipCode = false,
    this.employer = false,
    this.occupation = false,
    this.county = false,
    this.congressionalDistrict = false,
    this.amount = true,
    this.donationDate = true,
    this.paymentMethod = true,
    this.checkNumber = false,
    this.eventName = false,
    this.notes = false,
    this.thankYouSent = true,
    this.isRecurring = false,
  });

  DonorExportFields copyWith({
    bool? donorName,
    bool? email,
    bool? phone,
    bool? address,
    bool? city,
    bool? state,
    bool? zipCode,
    bool? employer,
    bool? occupation,
    bool? county,
    bool? congressionalDistrict,
    bool? amount,
    bool? donationDate,
    bool? paymentMethod,
    bool? checkNumber,
    bool? eventName,
    bool? notes,
    bool? thankYouSent,
    bool? isRecurring,
  }) {
    return DonorExportFields(
      donorName: donorName ?? this.donorName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      employer: employer ?? this.employer,
      occupation: occupation ?? this.occupation,
      county: county ?? this.county,
      congressionalDistrict:
          congressionalDistrict ?? this.congressionalDistrict,
      amount: amount ?? this.amount,
      donationDate: donationDate ?? this.donationDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      checkNumber: checkNumber ?? this.checkNumber,
      eventName: eventName ?? this.eventName,
      notes: notes ?? this.notes,
      thankYouSent: thankYouSent ?? this.thankYouSent,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  /// Returns list of selected column headers in display order
  List<String> get selectedFieldNames {
    final headers = <String>[];
    if (donorName) headers.add('Donor Name');
    if (email) headers.add('Email');
    if (phone) headers.add('Phone');
    if (address) headers.add('Address');
    if (city) headers.add('City');
    if (state) headers.add('State');
    if (zipCode) headers.add('ZIP Code');
    if (employer) headers.add('Employer');
    if (occupation) headers.add('Occupation');
    if (county) headers.add('County');
    if (congressionalDistrict) headers.add('Congressional District');
    if (amount) headers.add('Amount');
    if (donationDate) headers.add('Date');
    if (paymentMethod) headers.add('Payment Method');
    if (checkNumber) headers.add('Check #');
    if (eventName) headers.add('Event');
    if (notes) headers.add('Notes');
    if (thankYouSent) headers.add('Thank You Sent');
    if (isRecurring) headers.add('Recurring');
    return headers;
  }

  /// Returns the count of selected fields
  int get selectedCount {
    int count = 0;
    if (donorName) count++;
    if (email) count++;
    if (phone) count++;
    if (address) count++;
    if (city) count++;
    if (state) count++;
    if (zipCode) count++;
    if (employer) count++;
    if (occupation) count++;
    if (county) count++;
    if (congressionalDistrict) count++;
    if (amount) count++;
    if (donationDate) count++;
    if (paymentMethod) count++;
    if (checkNumber) count++;
    if (eventName) count++;
    if (notes) count++;
    if (thankYouSent) count++;
    if (isRecurring) count++;
    return count;
  }
}

/// Filter configuration for export
class DonorExportFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final String? paymentMethod;
  final bool? isRecurring;
  final bool? thankYouSent;

  const DonorExportFilters({
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.paymentMethod,
    this.isRecurring,
    this.thankYouSent,
  });

  DonorExportFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    String? paymentMethod,
    bool? isRecurring,
    bool? thankYouSent,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearMinAmount = false,
    bool clearMaxAmount = false,
    bool clearPaymentMethod = false,
    bool clearIsRecurring = false,
    bool clearThankYouSent = false,
  }) {
    return DonorExportFilters(
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      paymentMethod: clearPaymentMethod
          ? null
          : (paymentMethod ?? this.paymentMethod),
      isRecurring: clearIsRecurring ? null : (isRecurring ?? this.isRecurring),
      thankYouSent: clearThankYouSent
          ? null
          : (thankYouSent ?? this.thankYouSent),
    );
  }

  /// Returns true if any filter is active
  bool get hasActiveFilters {
    return startDate != null ||
        endDate != null ||
        minAmount != null ||
        maxAmount != null ||
        paymentMethod != null ||
        isRecurring != null ||
        thankYouSent != null;
  }

  /// Returns a human-readable summary of active filters
  String get filterSummary {
    final parts = <String>[];
    if (startDate != null || endDate != null) {
      if (startDate != null && endDate != null) {
        parts.add(
          'Date: ${_formatDate(startDate!)} - ${_formatDate(endDate!)}',
        );
      } else if (startDate != null) {
        parts.add('From: ${_formatDate(startDate!)}');
      } else {
        parts.add('To: ${_formatDate(endDate!)}');
      }
    }
    if (minAmount != null || maxAmount != null) {
      if (minAmount != null && maxAmount != null) {
        parts.add(
          'Amount: \$${minAmount!.toStringAsFixed(0)} - \$${maxAmount!.toStringAsFixed(0)}',
        );
      } else if (minAmount != null) {
        parts.add('Min: \$${minAmount!.toStringAsFixed(0)}');
      } else {
        parts.add('Max: \$${maxAmount!.toStringAsFixed(0)}');
      }
    }
    if (paymentMethod != null) parts.add('Method: $paymentMethod');
    if (isRecurring != null) parts.add(isRecurring! ? 'Recurring' : 'One-time');
    if (thankYouSent != null)
      parts.add(thankYouSent! ? 'Thanked' : 'Not thanked');
    return parts.isEmpty ? 'No filters' : parts.join(' | ');
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Data class for a donation row to be exported
class DonationExportRow {
  final String donorName;
  final String? email;
  final String? phone;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? employer;
  final String? occupation;
  final String? county;
  final String? congressionalDistrict;
  final double? amount;
  final DateTime? donationDate;
  final String? paymentMethod;
  final String? checkNumber;
  final String? eventName;
  final String? notes;
  final bool thankYouSent;
  final bool isRecurring;

  const DonationExportRow({
    required this.donorName,
    this.email,
    this.phone,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.employer,
    this.occupation,
    this.county,
    this.congressionalDistrict,
    this.amount,
    this.donationDate,
    this.paymentMethod,
    this.checkNumber,
    this.eventName,
    this.notes,
    this.thankYouSent = false,
    this.isRecurring = false,
  });

  /// Extract values based on selected fields in order
  List<String> getValues(DonorExportFields fields) {
    final values = <String>[];
    if (fields.donorName) values.add(donorName);
    if (fields.email) values.add(email ?? '');
    if (fields.phone) values.add(phone ?? '');
    if (fields.address) values.add(address ?? '');
    if (fields.city) values.add(city ?? '');
    if (fields.state) values.add(state ?? '');
    if (fields.zipCode) values.add(zipCode ?? '');
    if (fields.employer) values.add(employer ?? '');
    if (fields.occupation) values.add(occupation ?? '');
    if (fields.county) values.add(county ?? '');
    if (fields.congressionalDistrict) values.add(congressionalDistrict ?? '');
    if (fields.amount)
      values.add(amount != null ? '\$${amount!.toStringAsFixed(2)}' : '');
    if (fields.donationDate)
      values.add(donationDate != null ? _formatDate(donationDate!) : '');
    if (fields.paymentMethod) values.add(paymentMethod ?? '');
    if (fields.checkNumber) values.add(checkNumber ?? '');
    if (fields.eventName) values.add(eventName ?? '');
    if (fields.notes) values.add(notes ?? '');
    if (fields.thankYouSent) values.add(thankYouSent ? 'Yes' : 'No');
    if (fields.isRecurring) values.add(isRecurring ? 'Yes' : 'No');
    return values;
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
