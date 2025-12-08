import 'package:uuid/uuid.dart';
import 'form_field_config.dart';
import 'form_field_types.dart';

/// Pre-built form templates for common use cases
class FormTemplates {
  static const _uuid = Uuid();

  /// Get all available templates
  static List<FormTemplate> get allTemplates => [
        contactForm,
        feedbackForm,
        eventRegistration,
        jobApplication,
        surveyTemplate,
        newsletterSignup,
        customerSupport,
        orderForm,
        volunteerSignup,
        membershipApplication,
      ];

  /// Simple contact form
  static FormTemplate get contactForm => FormTemplate(
        id: 'contact_form',
        name: 'Contact Form',
        description: 'Basic contact form with name, email, phone, and message',
        category: 'General',
        icon: 'contact_mail',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Full Name',
            required: true,
            validatorTypes: ['minLength'],
            validation: {'minLength': 2},
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email Address',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.phone,
            label: 'Phone Number',
            validatorTypes: ['phoneNumber'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Message',
            required: true,
            minLines: 4,
            maxLines: 8,
            validatorTypes: ['minLength'],
            validation: {'minLength': 10},
          ),
        ],
      );

  /// Feedback form
  static FormTemplate get feedbackForm => FormTemplate(
        id: 'feedback_form',
        name: 'Feedback Form',
        description: 'Collect user feedback with ratings and comments',
        category: 'Feedback',
        icon: 'feedback',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Your Name',
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email (optional)',
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.rating,
            label: 'Overall Satisfaction',
            required: true,
            maxValue: 5,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'What did you like?',
            required: true,
            minLines: 3,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'What can we improve?',
            minLines: 3,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.radio,
            label: 'Would you recommend us?',
            required: true,
            options: [
              FormFieldOption(value: 'yes', label: 'Yes'),
              FormFieldOption(value: 'no', label: 'No'),
              FormFieldOption(value: 'maybe', label: 'Maybe'),
            ],
          ),
        ],
      );

  /// Event registration form
  static FormTemplate get eventRegistration => FormTemplate(
        id: 'event_registration',
        name: 'Event Registration',
        description: 'Register attendees for events',
        category: 'Events',
        icon: 'event',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Full Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.phone,
            label: 'Phone Number',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.touchSpin,
            label: 'Number of Guests',
            required: true,
            minValue: 1,
            maxValue: 10,
            initialValue: 1,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.checkboxGroup,
            label: 'Dietary Restrictions',
            options: [
              FormFieldOption(value: 'vegetarian', label: 'Vegetarian'),
              FormFieldOption(value: 'vegan', label: 'Vegan'),
              FormFieldOption(value: 'gluten_free', label: 'Gluten-Free'),
              FormFieldOption(value: 'dairy_free', label: 'Dairy-Free'),
              FormFieldOption(value: 'none', label: 'None'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.dropdown,
            label: 'T-Shirt Size',
            options: [
              FormFieldOption(value: 'xs', label: 'XS'),
              FormFieldOption(value: 's', label: 'S'),
              FormFieldOption(value: 'm', label: 'M'),
              FormFieldOption(value: 'l', label: 'L'),
              FormFieldOption(value: 'xl', label: 'XL'),
              FormFieldOption(value: 'xxl', label: 'XXL'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Special Requirements',
            minLines: 2,
          ),
        ],
      );

  /// Job application form
  static FormTemplate get jobApplication => FormTemplate(
        id: 'job_application',
        name: 'Job Application',
        description: 'Collect job applications with resume upload',
        category: 'Employment',
        icon: 'work',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Full Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.phone,
            label: 'Phone Number',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Position Applied For',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.filePicker,
            label: 'Resume/CV',
            required: true,
            allowedExtensions: ['pdf', 'doc', 'docx'],
            maxFileSizeMB: 5,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.filePicker,
            label: 'Cover Letter',
            allowedExtensions: ['pdf', 'doc', 'docx'],
            maxFileSizeMB: 5,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.url,
            label: 'LinkedIn Profile',
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Why do you want to work with us?',
            required: true,
            minLines: 4,
          ),
        ],
      );

  /// Survey template
  static FormTemplate get surveyTemplate => FormTemplate(
        id: 'survey_template',
        name: 'Survey',
        description: 'General purpose survey with various question types',
        category: 'Survey',
        icon: 'poll',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.radio,
            label: 'How often do you use our product?',
            required: true,
            options: [
              FormFieldOption(value: 'daily', label: 'Daily'),
              FormFieldOption(value: 'weekly', label: 'Weekly'),
              FormFieldOption(value: 'monthly', label: 'Monthly'),
              FormFieldOption(value: 'rarely', label: 'Rarely'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.slider,
            label: 'Rate your experience (1-10)',
            required: true,
            minValue: 1,
            maxValue: 10,
            divisions: 9,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.checkboxGroup,
            label: 'Which features do you use?',
            options: [
              FormFieldOption(value: 'feature1', label: 'Feature 1'),
              FormFieldOption(value: 'feature2', label: 'Feature 2'),
              FormFieldOption(value: 'feature3', label: 'Feature 3'),
              FormFieldOption(value: 'feature4', label: 'Feature 4'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Additional comments',
            minLines: 3,
          ),
        ],
      );

  /// Newsletter signup
  static FormTemplate get newsletterSignup => FormTemplate(
        id: 'newsletter_signup',
        name: 'Newsletter Signup',
        description: 'Simple newsletter subscription form',
        category: 'Marketing',
        icon: 'email',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'First Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Last Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email Address',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.filterChips,
            label: 'Topics of Interest',
            options: [
              FormFieldOption(value: 'tech', label: 'Technology'),
              FormFieldOption(value: 'business', label: 'Business'),
              FormFieldOption(value: 'lifestyle', label: 'Lifestyle'),
              FormFieldOption(value: 'news', label: 'News'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.checkbox,
            label: 'I agree to receive marketing emails',
            required: true,
          ),
        ],
      );

  /// Customer support ticket
  static FormTemplate get customerSupport => FormTemplate(
        id: 'customer_support',
        name: 'Support Ticket',
        description: 'Customer support request form',
        category: 'Support',
        icon: 'support_agent',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.dropdown,
            label: 'Priority',
            required: true,
            options: [
              FormFieldOption(value: 'low', label: 'Low'),
              FormFieldOption(value: 'medium', label: 'Medium'),
              FormFieldOption(value: 'high', label: 'High'),
              FormFieldOption(value: 'urgent', label: 'Urgent'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.dropdown,
            label: 'Category',
            required: true,
            options: [
              FormFieldOption(value: 'technical', label: 'Technical Issue'),
              FormFieldOption(value: 'billing', label: 'Billing'),
              FormFieldOption(value: 'account', label: 'Account'),
              FormFieldOption(value: 'other', label: 'Other'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Subject',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Description',
            required: true,
            minLines: 5,
            validatorTypes: ['minLength'],
            validation: {'minLength': 20},
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.filePicker,
            label: 'Attachments',
            allowMultipleFiles: true,
            maxFileSizeMB: 10,
          ),
        ],
      );

  /// Order form
  static FormTemplate get orderForm => FormTemplate(
        id: 'order_form',
        name: 'Order Form',
        description: 'Product/service order form',
        category: 'Sales',
        icon: 'shopping_cart',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Full Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.phone,
            label: 'Phone Number',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Shipping Address',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'City',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Zip Code',
            required: true,
            validatorTypes: ['zipCode'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.dropdown,
            label: 'Product',
            required: true,
            options: [
              FormFieldOption(value: 'product1', label: 'Product 1 - \$99'),
              FormFieldOption(value: 'product2', label: 'Product 2 - \$149'),
              FormFieldOption(value: 'product3', label: 'Product 3 - \$199'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.touchSpin,
            label: 'Quantity',
            required: true,
            minValue: 1,
            maxValue: 100,
            initialValue: 1,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Special Instructions',
            minLines: 2,
          ),
        ],
      );

  /// Volunteer signup
  static FormTemplate get volunteerSignup => FormTemplate(
        id: 'volunteer_signup',
        name: 'Volunteer Signup',
        description: 'Volunteer registration form',
        category: 'Nonprofit',
        icon: 'volunteer_activism',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Full Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.phone,
            label: 'Phone Number',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.datePicker,
            label: 'Date of Birth',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.checkboxGroup,
            label: 'Areas of Interest',
            required: true,
            options: [
              FormFieldOption(value: 'education', label: 'Education'),
              FormFieldOption(value: 'environment', label: 'Environment'),
              FormFieldOption(value: 'healthcare', label: 'Healthcare'),
              FormFieldOption(value: 'community', label: 'Community Service'),
              FormFieldOption(value: 'animals', label: 'Animal Welfare'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.radio,
            label: 'Availability',
            required: true,
            options: [
              FormFieldOption(value: 'weekdays', label: 'Weekdays'),
              FormFieldOption(value: 'weekends', label: 'Weekends'),
              FormFieldOption(value: 'both', label: 'Both'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.textarea,
            label: 'Why do you want to volunteer?',
            required: true,
            minLines: 4,
          ),
        ],
      );

  /// Membership application
  static FormTemplate get membershipApplication => FormTemplate(
        id: 'membership_application',
        name: 'Membership Application',
        description: 'Club/organization membership form',
        category: 'Membership',
        icon: 'card_membership',
        fields: [
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Full Name',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.email,
            label: 'Email',
            required: true,
            validatorTypes: ['email'],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.phone,
            label: 'Phone Number',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.text,
            label: 'Address',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.dropdown,
            label: 'Membership Type',
            required: true,
            options: [
              FormFieldOption(value: 'individual', label: 'Individual - \$50/year'),
              FormFieldOption(value: 'family', label: 'Family - \$75/year'),
              FormFieldOption(value: 'student', label: 'Student - \$25/year'),
              FormFieldOption(value: 'senior', label: 'Senior - \$35/year'),
            ],
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.imagePicker,
            label: 'Profile Photo',
            maxImages: 1,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.checkbox,
            label: 'I agree to the terms and conditions',
            required: true,
          ),
          FormFieldConfig(
            id: _uuid.v4(),
            type: FormFieldTypes.signaturePad,
            label: 'Signature',
            required: true,
          ),
        ],
      );
}

/// Form template model
class FormTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final List<FormFieldConfig> fields;

  const FormTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.fields,
  });
}
