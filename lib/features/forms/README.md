# Forms Management Feature

This directory contains the Forms Management feature for the Flutter CRM application.

## Overview

The Forms Management feature provides three main functionalities:
1. **Jobs/Opportunities** - Approve, edit, and publish job postings
2. **Forms** - Create, manage, and publish public forms
3. **Votes** - Create and manage member voting

## Directory Structure

```
forms/
├── models/               # Data models with Freezed
│   ├── form_field_config.dart
│   ├── form_schema.dart
│   ├── form_submission.dart
│   ├── job.dart
│   └── voting_form.dart
├── providers/           # State management (if needed)
├── services/            # Supabase service layer
│   ├── forms_service.dart
│   ├── jobs_service.dart
│   └── votes_service.dart
├── screens/             # UI screens
│   ├── forms_main_screen.dart
│   ├── jobs/
│   │   ├── jobs_list_screen.dart
│   │   └── job_detail_screen.dart
│   ├── forms_builder/
│   │   ├── forms_list_screen.dart
│   │   └── form_builder_screen.dart
│   └── votes/
│       ├── votes_list_screen.dart
│       ├── vote_builder_screen.dart
│       └── vote_detail_screen.dart
└── widgets/             # Reusable components
    ├── job_card.dart
    ├── form_card.dart
    └── vote_card.dart
```

## Setup Instructions

### 1. Generate Code

The models use Freezed and json_serializable for code generation. Run the following command to generate the required files:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate the following files for each model:
- `*.freezed.dart` - Freezed generated code for immutable models
- `*.g.dart` - JSON serialization/deserialization code

### 2. Database Tables Required

Ensure the following Supabase tables exist:

#### jobs
- id (uuid, primary key)
- created_at (timestamptz)
- updated_at (timestamptz)
- title (text)
- organization (text)
- description (text)
- requirements (text, nullable)
- qualifications (text, nullable)
- location (text, nullable)
- job_type (text)
- location_type (text, nullable)
- is_paid (boolean)
- contact_email (text)
- submitter_name (text)
- submitter_email (text)
- submitter_organization (text, nullable)
- status (text, default 'pending')
- approved_at (timestamptz, nullable)
- approved_by (uuid, nullable)
- rejection_reason (text, nullable)
- featured (boolean, default false)

#### form_schemas
- id (uuid, primary key)
- created_at (timestamptz)
- updated_at (timestamptz)
- created_by (uuid, nullable)
- title (text)
- description (text, nullable)
- form_type (text)
- schema (jsonb)
- status (text, default 'draft')

#### form_submissions
- id (uuid, primary key)
- created_at (timestamptz)
- form_id (uuid, foreign key)
- member_id (uuid, nullable)
- data (jsonb)
- submitter_email (text, nullable)
- submitter_name (text, nullable)

#### voting_forms
- id (uuid, primary key)
- created_at (timestamptz)
- updated_at (timestamptz)
- created_by (uuid, nullable)
- title (text)
- description (text, nullable)
- voting_type (text)
- options (jsonb)
- start_date (timestamptz, nullable)
- end_date (timestamptz, nullable)
- status (text, default 'draft')
- allow_multiple (boolean, default false)
- max_choices (integer, nullable)
- require_member (boolean, default true)

#### vote_submissions
- id (uuid, primary key)
- created_at (timestamptz)
- voting_form_id (uuid, foreign key)
- member_id (uuid, nullable)
- option_ids (jsonb)

### 3. Row Level Security (RLS)

Ensure appropriate RLS policies are set up for authenticated users to access these tables.

## Usage

The Forms Management feature is accessible from the main navigation bar. Click on "Forms" to access:
- **Jobs Tab** - View and manage job postings, approve/reject submissions
- **Forms Tab** - Create and manage custom forms with drag-and-drop builder
- **Votes Tab** - Create and manage voting forms for member engagement

## Features Implemented

### Jobs Management
- ✅ List all jobs with status filtering (All, Pending, Approved, Rejected)
- ✅ View job details
- ✅ Approve/reject jobs with feedback
- ✅ Real-time pending count badge
- ✅ Status indicators

### Forms Builder
- ✅ Create custom forms with multiple field types
- ✅ Add/remove fields dynamically
- ✅ Form type selection (Survey, Registration, Feedback)
- ✅ Save as draft or publish
- ✅ Edit existing forms

### Voting
- ✅ Create voting forms with multiple options
- ✅ Single choice, multiple choice, and ranked voting
- ✅ Set start/end dates
- ✅ View voting results
- ✅ Draft and publish functionality

## Next Steps

1. Run `flutter pub run build_runner build --delete-conflicting-outputs`
2. Create the required database tables in Supabase
3. Set up RLS policies
4. Test the implementation
5. Add additional features as needed (email notifications, advanced form fields, etc.)

## Notes

- The forms builder is a simplified version. For advanced form building, consider adding:
  - Field reordering (drag and drop)
  - Conditional logic
  - File uploads
  - Advanced validation rules
  - Custom styling options

- Email notifications for job approvals/rejections are marked as TODO in the services
- Consider adding more advanced voting features like ranked choice voting algorithms
