# Comprehensive Form Builder Guide

## Overview

The BlueBubbles app now includes a comprehensive form building system powered by the Flutter Form Builder ecosystem. This system supports **24+ field types** with **50+ validators**, enabling you to create sophisticated surveys, registration forms, feedback forms, voting forms, and job postings.

## Quick Start

### Creating a Form

1. Navigate to the **Forms** tab
2. Click the **"+"** button
3. Enter form title and description
4. Select form type (Survey, Registration, or Feedback)
5. Add fields using the **"Add Field"** button
6. Configure each field's properties and validation
7. Save as draft or publish immediately

### Filling Out a Form

1. Navigate to the **Forms** tab
2. Find an **active** form (green status badge)
3. Click the **eye icon** to view/fill the form
4. Complete all required fields
5. Submit the form

---

## Field Types

### Text Input Fields (6 types)

#### 1. **Text**
- Single-line text input
- Use for: Names, titles, short answers
- Properties: Max length, min/max lines

#### 2. **Email**
- Text input with email validation
- Auto email keyboard on mobile
- Built-in email format validation

#### 3. **Phone**
- Text input optimized for phone numbers
- Numeric keyboard on mobile
- Supports phone number validation

#### 4. **URL**
- Text input for website URLs
- URL keyboard on mobile
- Built-in URL format validation

#### 5. **Number**
- Numeric input field
- Number keyboard on mobile
- Supports numeric validation (min, max, etc.)

#### 6. **Text Area**
- Multi-line text input
- Use for: Long answers, comments, descriptions
- Configurable min/max lines

---

### Selection Fields (8 types)

#### 7. **Dropdown**
- Standard dropdown menu
- Single selection from options
- Use for: Country selection, status, categories

#### 8. **Searchable Dropdown**
- Dropdown with search functionality
- Great for long option lists
- Example: Searching through 100+ countries

#### 9. **Checkbox**
- Single checkbox (yes/no)
- Use for: Terms acceptance, opt-ins

#### 10. **Checkbox Group**
- Multiple checkboxes (select many)
- Use for: Multi-select interests, features

#### 11. **Radio Group**
- Radio buttons (select one)
- Use for: Gender, agreement scale, single choice

#### 12. **Choice Chips**
- Visual chip selection (single choice)
- Modern, compact UI
- Use for: Tags, categories

#### 13. **Filter Chips**
- Visual chip selection (multiple choice)
- Use for: Filters, multi-select tags

#### 14. **Switch**
- Toggle on/off
- Use for: Enable/disable features, preferences

---

### Date & Time Fields (4 types)

#### 15. **Date Picker**
- Select a single date
- Configure first/last selectable date
- Use for: Birth date, event date

#### 16. **Time Picker**
- Select a time
- 12 or 24-hour format
- Use for: Appointment time, schedule

#### 17. **Date & Time Picker**
- Combined date and time selection
- Use for: Event start/end, appointments

#### 18. **Date Range Picker**
- Select start and end dates
- Use for: Vacation dates, event duration

---

### Numeric Fields (4 types)

#### 19. **Slider**
- Visual slider for numeric values
- Configure min, max, divisions
- Use for: Ratings, age ranges, prices

#### 20. **Range Slider**
- Select a numeric range
- Two handles for min/max
- Use for: Price range, age range filters

#### 21. **Touch Spin**
- Numeric input with +/- buttons
- Configurable step size
- Use for: Quantity, count

#### 22. **Rating**
- Star rating (or custom icons)
- Configure max rating (default 5)
- Use for: Satisfaction, quality ratings

---

### Special Fields (3 types)

#### 23. **Color Picker**
- Visual color selection
- Material, block, or multiple picker styles
- Use for: Theme selection, customization

#### 24. **Signature Pad**
- Draw signature with finger/mouse
- Configurable canvas size
- Use for: Agreements, authorizations

#### 25. **Typeahead**
- Auto-complete text input
- Suggests options as you type
- Use for: Search, quick selection

---

### iOS (Cupertino) Fields (6 types)

iOS-styled fields for native Apple look and feel:

- **Cupertino Text Field** - iOS-styled text input
- **Cupertino Checkbox** - iOS-styled checkbox
- **Cupertino Switch** - iOS-styled toggle
- **Cupertino Slider** - iOS-styled slider
- **Cupertino Segmented Control** - iOS-styled segment selection
- **Cupertino Sliding Segmented Control** - iOS-styled sliding segments

---

## Validators

### Core Validators

- **Required** - Field must not be empty
- **Email** - Valid email format
- **URL** - Valid URL format

### String Validators

- **Min Length** - Minimum character count
- **Max Length** - Maximum character count
- **Min Words** - Minimum word count
- **Max Words** - Maximum word count
- **Alphabetical** - Only letters allowed
- **Lowercase** - Must be lowercase
- **Uppercase** - Must be uppercase
- **Contains** - Must contain specific text
- **Starts With** - Must start with text
- **Ends With** - Must end with text
- **Match Pattern** - Must match regex pattern
- **Single Line** - No line breaks allowed

### Numeric Validators

- **Numeric** - Must be a number
- **Integer** - Must be a whole number
- **Min** - Minimum value
- **Max** - Maximum value
- **Positive** - Must be positive
- **Negative** - Must be negative
- **Even** - Must be even
- **Odd** - Must be odd

### Date & Time Validators

- **Date** - Valid date
- **Date & Time** - Valid date and time
- **Time** - Valid time
- **Future Date** - Must be in the future
- **Past Date** - Must be in the past

### Contact Validators

- **Phone Number** - Valid phone number
- **First Name** - Valid first name
- **Last Name** - Valid last name

### Location Validators

- **City** - Valid city name
- **State** - Valid state
- **Country** - Valid country
- **Street** - Valid street address
- **Zip Code** - Valid zip/postal code

### Finance Validators

- **Credit Card** - Valid credit card number
- **CVC** - Valid card CVC
- **IBAN** - Valid IBAN

### Network Validators

- **IP Address** - Valid IP address
- **MAC Address** - Valid MAC address

### Security Validators

- **Password** - Strong password
- **Has Lowercase** - Contains lowercase letters
- **Has Uppercase** - Contains uppercase letters
- **Has Numbers** - Contains numbers
- **Has Special Chars** - Contains special characters

---

## Field Configuration

### Basic Properties

Every field has these properties:

- **Label** - Field name shown to user (required)
- **Placeholder** - Hint text in the field
- **Help Text** - Additional guidance below field
- **Required** - Whether field must be filled
- **Enabled** - Whether field can be edited

### Type-Specific Properties

#### Text Fields
- Max/min length
- Max/min lines (for text area)
- Keyboard type

#### Selection Fields
- Options list (value + label)
- Allow multiple selection
- Default value

#### Numeric Fields
- Min/max value
- Initial value
- Step size (for touch spin)
- Divisions (for sliders)

#### Date/Time Fields
- First selectable date
- Last selectable date
- Date format
- Time format

#### Special Fields
- Signature canvas size
- Color picker style
- Typeahead suggestions

---

## Form Types

### Survey
- Collect opinions and feedback
- Multiple field types supported
- Anonymous or identified responses

### Registration
- Sign up forms
- Member onboarding
- Event registration

### Feedback
- User feedback collection
- Bug reports
- Feature requests

### Voting Forms
- Special form type for voting
- Configure voting start/end dates
- Track vote counts
- Public or private results

### Job Postings
- Job listing forms
- Application tracking
- Status management (pending/approved/rejected)

---

## Best Practices

### Form Design

1. **Keep it short** - Only ask for necessary information
2. **Group related fields** - Organize logically
3. **Use appropriate field types** - Match field to data type
4. **Add help text** - Guide users when needed
5. **Set smart defaults** - Pre-fill when possible

### Validation

1. **Mark required fields** - Clear indication
2. **Use appropriate validators** - Match data expectations
3. **Provide clear error messages** - Built-in validation messages
4. **Don't over-validate** - Balance security with UX

### Field Selection Guide

| Use Case | Recommended Field |
|----------|------------------|
| Name | Text |
| Email | Email |
| Phone | Phone |
| Long text | Text Area |
| Select one from many | Radio Group / Dropdown |
| Select multiple | Checkbox Group / Filter Chips |
| Yes/No | Checkbox / Switch |
| Date | Date Picker |
| Rating | Rating / Slider |
| Color | Color Picker |
| Signature | Signature Pad |

---

## Examples

### Simple Contact Form

```
Fields:
1. Name (Text, required)
2. Email (Email, required, email validator)
3. Phone (Phone, phone validator)
4. Message (Text Area, required, min length 10)
```

### Event Registration Form

```
Fields:
1. Full Name (Text, required)
2. Email (Email, required, email validator)
3. Number of Guests (Touch Spin, min: 1, max: 10)
4. Dietary Restrictions (Checkbox Group, options: Vegan, Vegetarian, Gluten-Free, None)
5. Preferred Date (Date Picker, future date validator)
6. T-Shirt Size (Dropdown, options: XS, S, M, L, XL, XXL)
```

### Feedback Form

```
Fields:
1. Overall Satisfaction (Rating, max: 5, required)
2. What did you like? (Text Area, required)
3. What can we improve? (Text Area)
4. Feature Requests (Filter Chips, multiple selection)
5. Would you recommend us? (Radio Group, options: Yes, No, Maybe)
```

---

## Technical Details

### Packages Used

- **flutter_form_builder** (^9.4.1) - Core form functionality
- **form_builder_validators** (^11.0.0) - 50+ validators
- **form_builder_extra_fields** (^10.0.1) - Special fields (color, rating, signature, etc.)
- **form_builder_cupertino_fields** (^3.0.0) - iOS-styled fields

### Data Storage

Forms are stored in Supabase with the following structure:

- **form_schemas** - Form definitions
- **form_submissions** - User submissions
- **voting_forms** - Voting-specific data
- **jobs** - Job posting data

### Model Structure

```dart
FormFieldConfig {
  id: String
  type: String (field type)
  label: String
  placeholder: String?
  help: String?
  required: bool
  options: List<FormFieldOption>?
  validatorTypes: List<String>?
  validation: Map<String, dynamic>?
  // Type-specific properties...
}
```

---

## Troubleshooting

### Common Issues

**Q: Field not showing options**
A: Make sure you've added options in the Properties tab for selection fields

**Q: Validation not working**
A: Check that validators are configured in the Validation tab with required values

**Q: Can't submit form**
A: Ensure all required fields are filled and validation passes

**Q: Date picker not working**
A: Configure first/last dates in Properties tab

**Q: Form not appearing in list**
A: Check that form status is "active" - only active forms can be filled out

---

## Future Enhancements

Potential additions:
- Conditional field display (show/hide based on other fields)
- File upload fields
- Multi-page forms
- Form templates
- Advanced analytics
- Export form data (CSV, Excel)
- Custom validation rules
- Integration with external services

---

## API Reference

### Key Files

- `lib/features/forms/models/form_field_config.dart` - Field configuration model
- `lib/features/forms/models/form_field_types.dart` - All field type constants
- `lib/features/forms/models/form_validators.dart` - All validator definitions
- `lib/features/forms/widgets/field_config_dialog.dart` - Field configuration UI
- `lib/features/forms/widgets/form_field_renderer.dart` - Field rendering logic
- `lib/features/forms/screens/form_submission_screen.dart` - Form filling UI
- `lib/features/forms/services/forms_service.dart` - Form data service

---

## Support

For issues or questions:
1. Check this guide first
2. Review the code examples
3. Test with a simple form first
4. Create an issue on GitHub with details

---

**Last Updated:** 2025-12-08
**Version:** 1.0.0
