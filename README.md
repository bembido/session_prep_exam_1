# session_prep_1

Flutter session app that loads questions from a DOCX file, parses options and
answer keys, and runs a randomized quiz session.

## Features

- Reads quizzes from `assets/PO 5.1-5.3 answers.docx`.
- Extracts sections, questions, options, and answer keys.
- Shuffles questions and options for each run.
- Shows progress, score, and a summary at the end.

## Getting Started

This project is built with Flutter.

- Ensure the DOCX file is listed in `pubspec.yaml` under assets.
- Update the DOCX path in `lib/main.dart` if you change the file name.

A few resources to get you started:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
