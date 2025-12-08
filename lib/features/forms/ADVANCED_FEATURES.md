# Advanced Form Builder Features

## 🚀 New Features Overview

This document covers the advanced features added to the comprehensive form builder system.

---

## 📁 File Upload Fields

### File Picker
Upload any type of file with full control over allowed types and sizes.

**Features:**
- Multiple file upload support
- File type filtering (PDF, DOC, images, video, audio, or custom)
- Maximum file size limits
- File preview
- Allowed extensions configuration

**Configuration:**
```dart
FormFieldConfig(
  type: FormFieldTypes.filePicker,
  label: 'Upload Documents',
  allowMultipleFiles: true,
  allowedExtensions: ['pdf', 'doc', 'docx'],
  maxFileSizeMB: 10,
  fileTypeFilter: 'custom',
)
```

### Image Picker
Specialized image upload with camera and gallery support.

**Features:**
- Multiple image selection
- Camera capture
- Gallery selection
- Image quality control
- Size constraints (width/height)

**Configuration:**
```dart
FormFieldConfig(
  type: FormFieldTypes.imagePicker,
  label: 'Upload Photos',
  maxImages: 5,
  imageQuality: 0.8, // 80% quality
  maxImageWidth: 1920,
  maxImageHeight: 1080,
  allowCamera: true,
  allowGallery: true,
)
```

**Use Cases:**
- Resume/CV uploads in job applications
- Profile photo uploads
- Document verification
- Product images
- Receipt uploads

---

## 🔀 Conditional Field Logic

Show or hide fields based on other field values - create dynamic, intelligent forms that adapt to user input.

### How It Works

Fields can be configured to show/hide based on another field's value using various operators.

### Available Operators

- `equals` - Field value equals specific value
- `notEquals` - Field value does not equal specific value
- `contains` - String/array contains value
- `notContains` - String/array doesn't contain value
- `greaterThan` - Numeric value greater than
- `lessThan` - Numeric value less than
- `greaterThanOrEqual` - Numeric value ≥
- `lessThanOrEqual` - Numeric value ≤
- `isEmpty` - Field is empty
- `isNotEmpty` - Field has value

### Example: Conditional Registration

```dart
// Primary field
FormFieldConfig(
  id: 'registration_type',
  type: FormFieldTypes.radio,
  label: 'Registration Type',
  options: [
    FormFieldOption(value: 'individual', label: 'Individual'),
    FormFieldOption(value: 'organization', label: 'Organization'),
  ],
)

// Conditional field - only shown if "organization" is selected
FormFieldConfig(
  id: 'company_name',
  type: FormFieldTypes.text,
  label: 'Company Name',
  conditionalFieldId: 'registration_type',
  conditionalOperator: 'equals',
  conditionalValue: 'organization',
  showWhenConditionMet: true,
)
```

### Real-World Use Cases

1. **Job Applications**
   - Show "Portfolio URL" only if user selects "Designer" role
   - Show "Years of Experience" fields based on experience level

2. **Event Registration**
   - Show dietary preferences only if "Attending Dinner" is checked
   - Show guest names only if number of guests > 1

3. **Surveys**
   - Show follow-up questions based on rating
   - Branch to different question sets based on answers

4. **Order Forms**
   - Show shipping address only if "Ship to different address" is checked
   - Show gift message field only if "This is a gift" is selected

---

## 📄 Multi-Page Forms

Split long forms across multiple pages with progress tracking and validation per page.

### Features

- **Page-by-page validation** - Users must complete each page before advancing
- **Progress indicator** - Visual progress bar showing completion
- **Navigation controls** - Previous/Next buttons with smart state management
- **Single-page fallback** - Automatically renders as single page if pages aren't configured

### Usage

Assign page numbers to fields (0-indexed):

```dart
// Page 1 (Personal Info)
FormFieldConfig(
  id: 'name',
  type: FormFieldTypes.text,
  label: 'Full Name',
  pageNumber: 0,
)

FormFieldConfig(
  id: 'email',
  type: FormFieldTypes.email,
  label: 'Email',
  pageNumber: 0,
)

// Page 2 (Professional Info)
FormFieldConfig(
  id: 'company',
  type: FormFieldTypes.text,
  label: 'Company',
  pageNumber: 1,
)

FormFieldConfig(
  id: 'job_title',
  type: FormFieldTypes.text,
  label: 'Job Title',
  pageNumber: 1,
)

// Page 3 (Additional Info)
FormFieldConfig(
  id: 'bio',
  type: FormFieldTypes.textarea,
  label: 'Biography',
  pageNumber: 2,
)
```

### Implementation

Use the `MultiPageFormWidget` for automatic page management:

```dart
MultiPageFormWidget(
  fields: formFields,
  formKey: _formKey,
  onSubmit: _handleSubmit,
  showProgressIndicator: true, // Show progress bar
)
```

### Benefits

- **Reduced cognitive load** - Users focus on one section at a time
- **Better completion rates** - Smaller chunks feel less overwhelming
- **Improved validation** - Catch errors early, page by page
- **Mobile-friendly** - Less scrolling on small screens
- **Professional appearance** - Multi-step forms feel more polished

---

## 📋 Form Templates

10 pre-built professional form templates ready to use out of the box.

### Available Templates

1. **Contact Form**
   - Name, email, phone, message
   - Perfect for "Contact Us" pages

2. **Feedback Form**
   - Ratings, comments, recommendations
   - Customer satisfaction surveys

3. **Event Registration**
   - Attendee info, dietary restrictions, t-shirt size
   - Conferences, workshops, meetups

4. **Job Application**
   - Personal info, resume upload, cover letter
   - Recruiting and hiring

5. **Survey**
   - Multiple question types, ratings, checkboxes
   - General purpose surveys

6. **Newsletter Signup**
   - Name, email, topic preferences
   - Email marketing campaigns

7. **Support Ticket**
   - Priority, category, description, attachments
   - Customer support systems

8. **Order Form**
   - Shipping info, product selection, quantity
   - E-commerce orders

9. **Volunteer Signup**
   - Availability, interests, motivation
   - Nonprofit organizations

10. **Membership Application**
    - Personal info, membership type, photo, signature
    - Clubs and organizations

### How to Use Templates

```dart
import 'package:your_app/features/forms/models/form_templates.dart';

// Get all templates
final templates = FormTemplates.allTemplates;

// Use a specific template
final contactTemplate = FormTemplates.contactForm;

// Create form from template
final form = FormSchema(
  title: contactTemplate.name,
  description: contactTemplate.description,
  formType: 'survey',
  schema: FormSchemaData(
    fields: contactTemplate.fields,
  ),
);
```

### Customization

Templates are starting points - customize them:
- Add/remove fields
- Modify validation rules
- Adjust field properties
- Add conditional logic
- Split across pages

---

## 📊 Form Analytics

Track form performance with comprehensive analytics and insights.

### Tracked Metrics

**Form-Level:**
- **Views** - How many times form was viewed
- **Starts** - How many users began filling the form
- **Submissions** - Completed form submissions
- **Abandonments** - Users who left without submitting
- **Completion Rate** - (Submissions / Starts) × 100
- **Abandonment Rate** - (Abandonments / Starts) × 100

**Field-Level:**
- **Interactions** - How many times field was clicked/focused
- **Validation Errors** - Number of validation failures per field
- **Error Rate** - Helps identify confusing fields

**Time-Series:**
- Daily submission counts
- Trend analysis
- Peak usage times

### Implementation

```dart
final analytics = FormAnalyticsService();

// Track form view
await analytics.trackFormView(formId, userId);

// Track form start (first field interaction)
await analytics.trackFormStart(formId, userId);

// Track submission
await analytics.trackFormSubmission(formId, userId, submissionData);

// Track abandonment
await analytics.trackFormAbandonment(formId, userId, partialData);

// Get analytics summary
final summary = await analytics.getFormAnalytics(formId);
print('Completion Rate: ${summary.completionRate}%');
print('Total Submissions: ${summary.totalSubmissions}');

// Get field analytics
final fieldStats = await analytics.getFieldAnalytics(formId);
for (final field in fieldStats) {
  print('${field.fieldId}: ${field.interactions} interactions, ${field.validationErrors} errors');
}

// Get submission trends
final timeSeries = await analytics.getSubmissionTimeSeries(
  formId,
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
);
```

### Use Cases

**Optimization:**
- Identify fields with high error rates → simplify validation
- Find where users abandon → reduce friction
- Detect low completion rates → shorten form or improve UX

**Business Intelligence:**
- Track submission trends over time
- Measure form performance after changes
- Compare multiple forms

**A/B Testing:**
- Test different field orders
- Compare conditional vs. linear forms
- Evaluate multi-page vs. single-page

---

## 🎯 Best Practices

### Conditional Logic
- **Keep it simple** - Too many conditions confuse users
- **Show progress** - Indicate optional vs. required sections
- **Test thoroughly** - Verify all condition paths work
- **Provide feedback** - Explain why fields appear/disappear

### Multi-Page Forms
- **Logical grouping** - Group related fields together
- **3-7 pages max** - Too many pages increase abandonment
- **Save progress** - Consider auto-save for long forms
- **Clear page titles** - Help users understand each section

### File Uploads
- **Set size limits** - Prevent large files from crashing
- **Show file types** - Make allowed types clear in help text
- **Preview uploads** - Let users see what they uploaded
- **Validate early** - Check file types and sizes immediately

### Analytics
- **Privacy first** - Don't track PII without consent
- **Aggregate data** - Focus on trends, not individuals
- **Regular review** - Check analytics monthly
- **Act on insights** - Use data to improve forms

---

## 🔧 Technical Details

### Database Schema

**Form Analytics:**
```sql
CREATE TABLE form_analytics (
  id UUID PRIMARY KEY,
  form_id UUID NOT NULL,
  user_id UUID,
  event_type VARCHAR(20), -- 'view', 'start', 'submit', 'abandon'
  timestamp TIMESTAMP,
  metadata JSONB
);

CREATE TABLE form_field_analytics (
  id UUID PRIMARY KEY,
  form_id UUID NOT NULL,
  field_id VARCHAR(100),
  field_type VARCHAR(50),
  user_id UUID,
  event_type VARCHAR(20), -- 'interaction', 'validation_error'
  timestamp TIMESTAMP,
  metadata JSONB
);
```

### File Upload Storage

Files uploaded via file picker and image picker are stored using the platform's file picker system. For production, you should:

1. Upload files to cloud storage (Supabase Storage, AWS S3, etc.)
2. Store file URLs/paths in form submission data
3. Implement file size and type validation
4. Set up proper CORS and security rules

### Performance Considerations

- **Analytics are async** - Don't block form submission
- **Silent failures** - Analytics errors shouldn't break forms
- **Batch updates** - Consider batching analytics events
- **Indexes** - Add indexes on form_id and timestamp columns

---

## 🚦 Migration Guide

### Updating Existing Forms

1. **Run Freezed code generation** after model updates:
   ```bash
   flutter pub run build_runner build
   ```

2. **Update database** if adding analytics:
   - Create analytics tables
   - Add indexes for performance

3. **Gradual rollout** for new features:
   - Start with file uploads
   - Add conditional logic to key forms
   - Enable multi-page for longest forms
   - Turn on analytics last

### Backwards Compatibility

All new features are opt-in:
- Forms without pageNumber render as single page
- Fields without conditional logic always show
- Analytics tracking is independent

---

## 📚 Additional Resources

- **Form Builder Guide** - See FORM_BUILDER_GUIDE.md for core features
- **API Documentation** - Check source code comments
- **Examples** - Explore form templates for real-world usage

---

**Last Updated:** 2025-12-08
**Version:** 2.0.0
