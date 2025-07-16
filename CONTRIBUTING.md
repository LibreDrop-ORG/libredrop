# Contributing to LibreDrop

First off, thank you for considering contributing to LibreDrop! It's people like you that make LibreDrop such a great tool.

## Development Setup

1.  **Fork the repository** on GitHub.
2.  **Clone your fork** locally:
    ```bash
    git clone https://github.com/YOUR_USERNAME/libredrop.git
    cd libredrop
    ```
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Run the app:**
    ```bash
    flutter run
    ```

## Code Style and Formatting

This project uses the standard Flutter lints. Please run the analyzer to check for issues before submitting a pull request:

```bash
flutter analyze
```

## Pull Request Process

1.  Ensure any install or build dependencies are removed before the end of the layer when doing a build.
2.  Update the `README.md` with details of changes to the interface, this includes new environment variables, exposed ports, useful file locations and container parameters.
3.  Increase the version numbers in any examples files and the `README.md` to the new version that this Pull Request would represent. The versioning scheme we use is [SemVer](http://semver.org/).
4.  You may merge the Pull Request in once you have the sign-off of two other developers, or if you do not have permission to do that, you may request the second reviewer to merge it for you.

## Issue Reporting

We use GitHub issues to track public bugs. Please ensure your description is clear and has sufficient instructions to be able to reproduce the issue.

### Bug Reports

When reporting a bug, please include:

*   A clear and descriptive title.
*   A detailed description of the problem.
*   Steps to reproduce the bug.
*   The expected behavior and what actually happened.
*   Your operating system, and the version of LibreDrop you're using.

### Feature Requests

When suggesting a new feature, please include:

*   A clear and descriptive title.
*   A detailed description of the proposed feature and its benefits.
*   Any mockups or examples of how the feature would work.

## Testing

Please add tests for any new features or bug fixes. This project uses the standard Flutter testing framework.

Run tests with:

```bash
flutter test
```

## Release Process

The release process is handled by the project maintainers.