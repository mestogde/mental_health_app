# PROJECT_CONTEXT.md

## Project
Flutter mobile application for a mental health center. The app supports patients between consultations and helps with prevention of social anxiety and communication difficulties.

The application has two access modes:
1. Guest mode
2. Extended patient mode after QR activation

The app is developed as an MVP for a graduation project.

## Current status
Flutter project is created.
Supabase is connected.
The Android phone successfully loads guest materials from the `materials` table.
The project should stay simple and suitable for MVP.

## Tech stack
- Flutter
- Dart
- Supabase
- PostgreSQL
- Android-first MVP
- VS Code

## Design system
Main colors:
- Background: #EEEEEE
- Surface: #F7F7F7
- Main dark text: #191919
- Pink accent: #F1D4D4
- Yellow accent: #F7D784
- Blue accent: #A8CDEA
- Green status: #C5EEC8
- Grey status: #AFAFAF

Typography:
- Plus Jakarta Sans for the splash screen title
- Golos Text for the main interface
If custom fonts are not added yet, use Google Fonts.

Interface style:
- Soft rounded cards
- Calm light background
- Large readable headings
- Bottom navigation
- Status chips for access/status labels
- Minimal visual noise
- No harsh medical visual style

## Supabase tables
Main tables:
- patients
- specialists
- consultations
- materials
- material_views
- tests
- test_attempts
- patient_answers
- state_notes
- recommendations
- events
- event_moderation
- event_requests

## Guest mode
Available screens:
- Splash screen
- Guest home screen
- Articles list
- Tests list
- Some articles and tests are locked
- Locked sections lead to QR activation screen

Guest can:
- view open educational materials
- view open diagnostic tests
- see locked cards
- start activation of extended access

## Extended patient mode
Available screens:
- PIN-code login
- Main screen with reminders
- Profile
- Doctor recommendations
- State notes
- New state note
- Events
- My events
- Event details
- Event participation requests
- Calendar
- Create event

Patient can:
- read all available materials
- pass tests
- view doctor recommendations
- create state notes
- view and create events
- send participation requests
- accept or reject requests for own events

## Important implementation rules
- Do not overcomplicate architecture.
- Keep the app suitable for a fast MVP.
- Use Supabase for data loading.
- Do not remove existing Supabase initialization.
- Do not hardcode too much mock data if real Supabase data is available.
- Prefer small reusable widgets.
- Run `flutter analyze` after changes when possible.
- Avoid adding unnecessary packages.