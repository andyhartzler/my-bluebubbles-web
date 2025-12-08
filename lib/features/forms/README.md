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
│   ├── job_application.dart
│   └── voting_form.dart
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

**Note:** The code WILL NOT compile until you run this command.

### 2. Database Schema

The database schema already exists in Supabase with the following tables:

#### jobs
- Stores job postings with approval workflow
- Fields include compensation (salary_range, hourly_rate), contact info, application tracking
- Statuses: pending, approved, rejected, expired, archived
- Auto-generates slugs for SEO-friendly URLs
- Triggers: auto_expire_jobs(), generate_job_slug()

#### job_applications
- Stores applications for jobs
- Links to jobs and optionally to members
- Auto-updates application_count on jobs table

#### form_schemas
- Stores all form definitions including regular forms AND voting forms
- form_type: 'survey', 'registration', 'feedback', 'vote'
- schema field contains JSONB with form structure
- settings field for form configuration
- Voting-specific fields: voting_starts_at, voting_ends_at, eligible_members, results_public, results_data

#### form_submissions
- Stores form submission responses
- data field contains JSONB with user responses
- Links to form_schemas and optionally to members

#### votes
- Stores individual vote submissions
- vote_data contains JSONB with vote choices
- Unique constraint: one vote per member per voting form
- Triggers automatically update results_data on form_schemas

#### voting_forms (VIEW)
- Read-only view of form_schemas WHERE form_type='vote'
- Provides convenient access to voting forms

## Database Functions

The schema includes helper functions:

- `can_member_vote(member_id, voting_form_id)` - Check if member is eligible to vote
- `get_form_submission_count(form_id)` - Count submissions for a form
- `get_vote_results(voting_form_id)` - Get aggregated vote results
- `auto_expire_jobs()` - Mark expired jobs
- `close_expired_votes()` - Close voting after end date

## Architecture Notes

### Voting System

Voting forms are stored in the `form_schemas` table with `form_type='vote'`. This unified approach:
- Reuses the forms infrastructure
- Stores voting options in the schema.fields JSONB
- Uses voting-specific fields (voting_starts_at, voting_ends_at, etc.)
- Individual votes go in the `votes` table
- Results are auto-aggregated in results_data field

### Data Flow

1. **Jobs**: User submits → Status='pending' → Admin approves/rejects → Status='approved'/'rejected'
2. **Forms**: Admin creates → Status='draft' → Publishes → Status='active'
3. **Votes**: Admin creates vote form (form_type='vote') → Members cast votes in `votes` table → Results aggregated automatically

## Usage

The Forms Management feature is accessible from the main navigation bar. Click on "Forms" to access:
- **Jobs Tab** - View and manage job postings, approve/reject submissions
- **Forms Tab** - Create and manage custom forms
- **Votes Tab** - Create and manage voting forms for member engagement

## Features Implemented

### Jobs Management
- ✅ List all jobs with status filtering (All, Pending, Approved, Rejected)
- ✅ View job details including compensation, requirements, contact info
- ✅ Approve/reject jobs with feedback
- ✅ Real-time pending count badge
- ✅ Status indicators
- ✅ Slug auto-generation for SEO
- ✅ Application tracking (count, view count)

### Forms Builder
- ✅ Create custom forms with multiple field types
- ✅ Add/remove fields dynamically
- ✅ Form type selection (Survey, Registration, Feedback)
- ✅ Save as draft or publish
- ✅ Edit existing forms
- ✅ View form submissions

### Voting
- ✅ Create voting forms stored in form_schemas
- ✅ Set start/end dates for voting periods
- ✅ View voting results from results_data
- ✅ Draft and publish functionality
- ✅ Member eligibility checking via can_member_vote()
- ✅ Automatic results aggregation via database triggers

## Model Changes from Original Design

The models have been updated to match the actual Supabase schema:

### Job Model
- Added: salary_range, hourly_rate, contact_name, contact_phone, application_url, application_instructions
- Added: submitter_phone, expires_at, slug, tags[], application_count, view_count
- job_type values: 'full-time', 'part-time', 'internship', 'volunteer', 'contract'

### FormSchema Model
- Added: settings (JSONB)
- Added voting fields: voting_starts_at, voting_ends_at, eligible_members, results_public, results_data

### VotingForm Model
- Now maps to form_schemas table with form_type='vote'
- Uses schema field for storing options
- Uses voting-specific fields from form_schemas

### New Models
- JobApplication - for job application submissions

## Next Steps

1. ✅ Run `flutter pub run build_runner build --delete-conflicting-outputs`
2. Test the implementation
3. Update UI screens to use actual schema fields
4. Add file upload support for resumes (job applications)
5. Implement email notifications (marked as TODO in services)
6. Add more advanced form field types as needed

## Notes

- All database operations use Row Level Security (RLS) policies
- The schema includes comprehensive triggers and functions
- Voting results are automatically calculated by database triggers
- Form schemas support JSONB for flexible field definitions
- The system supports both anonymous and authenticated submissions depending on RLS policies

## Email Notifications (TODO)

The following email notifications are marked as TODO in the services:
- Job approval confirmation (jobs_service.dart:49)
- Job rejection notification (jobs_service.dart:58)

These should be implemented using Supabase Edge Functions or a third-party service.
