/// All available validators from form_builder_validators
class FormValidators {
  // Core validators
  static const String required = 'required';
  static const String email = 'email';
  static const String url = 'url';
  static const String equal = 'equal';
  static const String notEqual = 'notEqual';

  // String validators
  static const String minLength = 'minLength';
  static const String maxLength = 'maxLength';
  static const String match = 'match'; // regex pattern
  static const String matchNot = 'matchNot';
  static const String alphabetical = 'alphabetical';
  static const String lowercase = 'lowercase';
  static const String uppercase = 'uppercase';
  static const String contains = 'contains';
  static const String startsWith = 'startsWith';
  static const String endsWith = 'endsWith';
  static const String singleLine = 'singleLine';
  static const String minWordsCount = 'minWordsCount';
  static const String maxWordsCount = 'maxWordsCount';

  // Numeric validators
  static const String numeric = 'numeric';
  static const String integer = 'integer';
  static const String min = 'min';
  static const String max = 'max';
  static const String between = 'between';
  static const String positiveNumber = 'positiveNumber';
  static const String negativeNumber = 'negativeNumber';
  static const String evenNumber = 'evenNumber';
  static const String oddNumber = 'oddNumber';
  static const String prime = 'prime';
  static const String notZeroNumber = 'notZeroNumber';

  // Date/Time validators
  static const String date = 'date';
  static const String dateTime = 'dateTime';
  static const String time = 'time';
  static const String dateFuture = 'dateFuture';
  static const String datePast = 'datePast';
  static const String dateRange = 'dateRange';

  // Network validators
  static const String phoneNumber = 'phoneNumber';
  static const String ip = 'ip';
  static const String macAddress = 'macAddress';
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String portNumber = 'portNumber';

  // Finance validators
  static const String creditCard = 'creditCard';
  static const String creditCardCVC = 'creditCardCVC';
  static const String creditCardExpirationDate = 'creditCardExpirationDate';
  static const String iban = 'iban';
  static const String bic = 'bic';

  // Identity validators
  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String username = 'username';
  static const String password = 'password';
  static const String ssn = 'ssn';
  static const String passportNumber = 'passportNumber';
  static const String city = 'city';
  static const String state = 'state';
  static const String country = 'country';
  static const String street = 'street';
  static const String zipCode = 'zipCode';

  // File validators
  static const String fileExtension = 'fileExtension';
  static const String fileName = 'fileName';
  static const String fileSize = 'fileSize';
  static const String mimeType = 'mimeType';

  // Boolean validators (character requirements)
  static const String hasLowercaseChars = 'hasLowercaseChars';
  static const String hasUppercaseChars = 'hasUppercaseChars';
  static const String hasNumericChars = 'hasNumericChars';
  static const String hasSpecialChars = 'hasSpecialChars';

  // Use-case validators
  static const String uuid = 'uuid';
  static const String isbn = 'isbn';
  static const String json = 'json';
  static const String base64 = 'base64';
  static const String colorCode = 'colorCode';
  static const String languageCode = 'languageCode';
  static const String licensePlate = 'licensePlate';
  static const String vin = 'vin';
  static const String duns = 'duns';

  /// Get validators grouped by category
  static Map<String, List<ValidatorInfo>> get categorizedValidators => {
        'Core': [
          ValidatorInfo(required, 'Required', 'Field must not be empty', requiresValue: false),
          ValidatorInfo(email, 'Email', 'Must be a valid email address', requiresValue: false),
          ValidatorInfo(url, 'URL', 'Must be a valid URL', requiresValue: false),
        ],
        'String Length': [
          ValidatorInfo(minLength, 'Min Length', 'Minimum character count', requiresValue: true, valueType: 'int'),
          ValidatorInfo(maxLength, 'Max Length', 'Maximum character count', requiresValue: true, valueType: 'int'),
          ValidatorInfo(minWordsCount, 'Min Words', 'Minimum word count', requiresValue: true, valueType: 'int'),
          ValidatorInfo(maxWordsCount, 'Max Words', 'Maximum word count', requiresValue: true, valueType: 'int'),
        ],
        'String Pattern': [
          ValidatorInfo(alphabetical, 'Alphabetical', 'Only letters allowed', requiresValue: false),
          ValidatorInfo(lowercase, 'Lowercase', 'Must be lowercase', requiresValue: false),
          ValidatorInfo(uppercase, 'Uppercase', 'Must be uppercase', requiresValue: false),
          ValidatorInfo(contains, 'Contains', 'Must contain specific text', requiresValue: true, valueType: 'string'),
          ValidatorInfo(startsWith, 'Starts With', 'Must start with text', requiresValue: true, valueType: 'string'),
          ValidatorInfo(endsWith, 'Ends With', 'Must end with text', requiresValue: true, valueType: 'string'),
          ValidatorInfo(match, 'Match Pattern', 'Must match regex pattern', requiresValue: true, valueType: 'string'),
          ValidatorInfo(singleLine, 'Single Line', 'No line breaks allowed', requiresValue: false),
        ],
        'Numeric': [
          ValidatorInfo(numeric, 'Numeric', 'Must be a number', requiresValue: false),
          ValidatorInfo(integer, 'Integer', 'Must be a whole number', requiresValue: false),
          ValidatorInfo(min, 'Minimum', 'Minimum value', requiresValue: true, valueType: 'double'),
          ValidatorInfo(max, 'Maximum', 'Maximum value', requiresValue: true, valueType: 'double'),
          ValidatorInfo(positiveNumber, 'Positive', 'Must be positive', requiresValue: false),
          ValidatorInfo(negativeNumber, 'Negative', 'Must be negative', requiresValue: false),
          ValidatorInfo(evenNumber, 'Even Number', 'Must be even', requiresValue: false),
          ValidatorInfo(oddNumber, 'Odd Number', 'Must be odd', requiresValue: false),
        ],
        'Date & Time': [
          ValidatorInfo(date, 'Date', 'Must be a valid date', requiresValue: false),
          ValidatorInfo(dateTime, 'Date & Time', 'Must be valid date and time', requiresValue: false),
          ValidatorInfo(time, 'Time', 'Must be a valid time', requiresValue: false),
          ValidatorInfo(dateFuture, 'Future Date', 'Must be in the future', requiresValue: false),
          ValidatorInfo(datePast, 'Past Date', 'Must be in the past', requiresValue: false),
        ],
        'Contact Info': [
          ValidatorInfo(phoneNumber, 'Phone Number', 'Valid phone number', requiresValue: false),
          ValidatorInfo(firstName, 'First Name', 'Valid first name', requiresValue: false),
          ValidatorInfo(lastName, 'Last Name', 'Valid last name', requiresValue: false),
        ],
        'Location': [
          ValidatorInfo(city, 'City', 'Valid city name', requiresValue: false),
          ValidatorInfo(state, 'State', 'Valid state', requiresValue: false),
          ValidatorInfo(country, 'Country', 'Valid country', requiresValue: false),
          ValidatorInfo(street, 'Street', 'Valid street address', requiresValue: false),
          ValidatorInfo(zipCode, 'Zip Code', 'Valid zip/postal code', requiresValue: false),
        ],
        'Finance': [
          ValidatorInfo(creditCard, 'Credit Card', 'Valid credit card number', requiresValue: false),
          ValidatorInfo(creditCardCVC, 'CVC', 'Valid card CVC', requiresValue: false),
          ValidatorInfo(iban, 'IBAN', 'Valid IBAN', requiresValue: false),
        ],
        'Network': [
          ValidatorInfo(ip, 'IP Address', 'Valid IP address', requiresValue: false),
          ValidatorInfo(macAddress, 'MAC Address', 'Valid MAC address', requiresValue: false),
        ],
        'Security': [
          ValidatorInfo(password, 'Password', 'Strong password', requiresValue: false),
          ValidatorInfo(hasLowercaseChars, 'Has Lowercase', 'Contains lowercase letters', requiresValue: false),
          ValidatorInfo(hasUppercaseChars, 'Has Uppercase', 'Contains uppercase letters', requiresValue: false),
          ValidatorInfo(hasNumericChars, 'Has Numbers', 'Contains numbers', requiresValue: false),
          ValidatorInfo(hasSpecialChars, 'Has Special Chars', 'Contains special characters', requiresValue: false),
        ],
      };

  /// Get all validators as a flat list
  static List<ValidatorInfo> get allValidators {
    return categorizedValidators.values.expand((list) => list).toList();
  }

  /// Get validator info by type
  static ValidatorInfo? getValidatorInfo(String type) {
    return allValidators.firstWhere(
      (v) => v.value == type,
      orElse: () => ValidatorInfo(type, type, 'Custom validator', requiresValue: false),
    );
  }
}

/// Information about a validator
class ValidatorInfo {
  final String value;
  final String label;
  final String description;
  final bool requiresValue;
  final String? valueType; // 'int', 'double', 'string', 'date'

  const ValidatorInfo(
    this.value,
    this.label,
    this.description, {
    required this.requiresValue,
    this.valueType,
  });
}
