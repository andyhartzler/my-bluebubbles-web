/// All supported form field types from flutter_form_builder ecosystem
class FormFieldTypes {
  // Basic text input fields
  static const String text = 'text';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String textarea = 'textarea';
  static const String url = 'url';
  static const String number = 'number';

  // Selection fields
  static const String dropdown = 'dropdown';
  static const String checkbox = 'checkbox';
  static const String checkboxGroup = 'checkbox_group';
  static const String radio = 'radio';
  static const String choiceChips = 'choice_chips';
  static const String filterChips = 'filter_chips';
  static const String switchField = 'switch';
  static const String searchableDropdown = 'searchable_dropdown';

  // Date and time fields
  static const String datePicker = 'date_picker';
  static const String timePicker = 'time_picker';
  static const String dateTimePicker = 'date_time_picker';
  static const String dateRangePicker = 'date_range_picker';

  // Numeric fields
  static const String slider = 'slider';
  static const String rangeSlider = 'range_slider';
  static const String touchSpin = 'touch_spin';
  static const String rating = 'rating';

  // Special fields
  static const String colorPicker = 'color_picker';
  static const String signaturePad = 'signature_pad';
  static const String typeahead = 'typeahead';

  // Cupertino (iOS) fields
  static const String cupertinoTextField = 'cupertino_text_field';
  static const String cupertinoCheckbox = 'cupertino_checkbox';
  static const String cupertinoSwitch = 'cupertino_switch';
  static const String cupertinoSlider = 'cupertino_slider';
  static const String cupertinoSegmentedControl = 'cupertino_segmented_control';
  static const String cupertinoSlidingSegmentedControl = 'cupertino_sliding_segmented_control';

  /// Get all available field types grouped by category
  static Map<String, List<FieldTypeInfo>> get categorizedTypes => {
        'Text Input': [
          FieldTypeInfo(text, 'Text', 'Single line text input'),
          FieldTypeInfo(email, 'Email', 'Email address input with validation'),
          FieldTypeInfo(phone, 'Phone', 'Phone number input'),
          FieldTypeInfo(url, 'URL', 'Website URL input'),
          FieldTypeInfo(number, 'Number', 'Numeric input'),
          FieldTypeInfo(textarea, 'Text Area', 'Multi-line text input'),
        ],
        'Selection': [
          FieldTypeInfo(dropdown, 'Dropdown', 'Single selection dropdown'),
          FieldTypeInfo(searchableDropdown, 'Searchable Dropdown', 'Dropdown with search functionality'),
          FieldTypeInfo(checkbox, 'Checkbox', 'Single checkbox'),
          FieldTypeInfo(checkboxGroup, 'Checkbox Group', 'Multiple checkbox options'),
          FieldTypeInfo(radio, 'Radio Group', 'Single selection from options'),
          FieldTypeInfo(choiceChips, 'Choice Chips', 'Single selection chips'),
          FieldTypeInfo(filterChips, 'Filter Chips', 'Multiple selection chips'),
          FieldTypeInfo(switchField, 'Switch', 'Toggle switch'),
        ],
        'Date & Time': [
          FieldTypeInfo(datePicker, 'Date Picker', 'Select a date'),
          FieldTypeInfo(timePicker, 'Time Picker', 'Select a time'),
          FieldTypeInfo(dateTimePicker, 'Date & Time', 'Select date and time'),
          FieldTypeInfo(dateRangePicker, 'Date Range', 'Select start and end dates'),
        ],
        'Numeric': [
          FieldTypeInfo(slider, 'Slider', 'Numeric value slider'),
          FieldTypeInfo(rangeSlider, 'Range Slider', 'Select a numeric range'),
          FieldTypeInfo(touchSpin, 'Touch Spin', 'Increment/decrement buttons'),
          FieldTypeInfo(rating, 'Rating', 'Star or icon rating'),
        ],
        'Special': [
          FieldTypeInfo(colorPicker, 'Color Picker', 'Select a color'),
          FieldTypeInfo(signaturePad, 'Signature Pad', 'Draw signature'),
          FieldTypeInfo(typeahead, 'Typeahead', 'Auto-complete text input'),
        ],
        'iOS (Cupertino)': [
          FieldTypeInfo(cupertinoTextField, 'Text Field (iOS)', 'iOS-styled text input'),
          FieldTypeInfo(cupertinoCheckbox, 'Checkbox (iOS)', 'iOS-styled checkbox'),
          FieldTypeInfo(cupertinoSwitch, 'Switch (iOS)', 'iOS-styled switch'),
          FieldTypeInfo(cupertinoSlider, 'Slider (iOS)', 'iOS-styled slider'),
          FieldTypeInfo(cupertinoSegmentedControl, 'Segmented Control (iOS)', 'iOS-styled segmented control'),
          FieldTypeInfo(cupertinoSlidingSegmentedControl, 'Sliding Segmented (iOS)', 'iOS-styled sliding segments'),
        ],
      };

  /// Get all field types as a flat list
  static List<FieldTypeInfo> get allTypes {
    return categorizedTypes.values.expand((list) => list).toList();
  }

  /// Check if a field type requires options
  static bool requiresOptions(String type) {
    return [
      dropdown,
      checkboxGroup,
      radio,
      choiceChips,
      filterChips,
      searchableDropdown,
      cupertinoSegmentedControl,
      cupertinoSlidingSegmentedControl,
    ].contains(type);
  }

  /// Check if a field type is numeric
  static bool isNumeric(String type) {
    return [
      number,
      slider,
      rangeSlider,
      touchSpin,
      rating,
      cupertinoSlider,
    ].contains(type);
  }

  /// Check if a field type is date/time related
  static bool isDateTime(String type) {
    return [
      datePicker,
      timePicker,
      dateTimePicker,
      dateRangePicker,
    ].contains(type);
  }

  /// Check if a field type is Cupertino (iOS)
  static bool isCupertino(String type) {
    return [
      cupertinoTextField,
      cupertinoCheckbox,
      cupertinoSwitch,
      cupertinoSlider,
      cupertinoSegmentedControl,
      cupertinoSlidingSegmentedControl,
    ].contains(type);
  }
}

/// Information about a field type
class FieldTypeInfo {
  final String value;
  final String label;
  final String description;

  const FieldTypeInfo(this.value, this.label, this.description);
}
