# AGENT Instructions

This repository contains a Flutter application for local network file sharing.

## Coding Guidelines
- Place all Dart/Flutter source files under the `lib/` directory.
- Keep `pubspec.yaml` up to date with any new dependencies.
- Format all Dart files using `dart format .` (or `flutter format .`) before committing.
- Ensure the app builds with `flutter analyze` to catch any static analysis issues.

## Documentation
- Update `README.md` whenever new features or setup steps are added.

## Testing
- If any widget or unit tests are added, run `flutter test` and ensure it passes.
- At minimum, run `flutter analyze` after changes to verify there are no analyzer warnings.

## Team Roles

* **Product Manager**: pablojavier. He holds the vision for LibreDrop. He decides what the app should do, who the users are, and what features are required to meet their needs.
* **Software Architect**: pablojavier. He makes the high-level strategic decisions about the technology stack, the application's structure, and the data model. He might consult Claude for options, but the final architectural blueprint is his.
* **Lead Developer**: pablojavier. He is the senior engineering authority, responsible for breaking down the architectural vision into specific coding tasks, reviewing the generated code, and integrating all the pieces into a functioning whole.
* **Pair Programmer / Coder**: Claude. The LLM acts as an incredibly fast and knowledgeable pair programmer. It writes functions, classes, boilerplate code, and algorithms based on the specific, detailed prompts given by pablojavier.
* **UI/UX Designer**: pablojavier (as Director) & Claude (as Implementer). pablojavier defines the user experience, the layout, and the desired "feel" of the app. Claude then generates the front-end code (HTML, CSS, etc.) to implement that design.
* **QA Engineer**: pablojavier & Claude. This is a shared role. pablojavier defines the testing strategy, but he can direct Claude to write unit tests, integration tests, and suggest edge cases to check. pablojavier performs the final user acceptance testing.
* **DevOps Engineer**: pablojavier. He is responsible for the final infrastructure, build process, and deployment. He would absolutely use Claude to generate Dockerfiles, CI/CD pipeline configurations, and deployment scripts, but he manages the live environment.
* **Mentor & Business Advisor**: moodler. Provides strategic guidance, industry insights, and business perspective to help shape LibreDrop's direction. Serves as a sounding board for major decisions, offers feedback on product-market fit, and shares experience from similar ventures. Acts as general inspiration and motivational support throughout the development journey.

