# LibreDrop UI Testing Suite

This directory contains comprehensive tests for the LibreDrop user interface revamp, ensuring all components work correctly across different screen sizes, states, and accessibility requirements.

## Test Structure

### Widget Tests (`widget_test.dart`)
- **ConnectionStatusBanner Component Tests**
  - Connected, disconnected, and error states
  - Animation transitions and timing
  - Semantic labels and accessibility
  - Error handling and null value safety
  - Responsive design adaptation

- **PulsingIcon Component Tests**
  - Active vs inactive animation states
  - Animation controller lifecycle
  - Theme color integration
  - Performance validation

- **Integration with Material Design**
  - Theme compatibility (light/dark)
  - Color scheme compliance
  - Typography consistency

### Integration Tests (`integration_test.dart`)
- **Full Application Flow**
  - App startup and initialization
  - Navigation between screens
  - Settings page integration
  - Back navigation handling

- **Peer Discovery Simulation**
  - Manual IP connection dialog
  - Form validation testing
  - Invalid input handling
  - Connection attempt flow

- **Error Recovery Testing**
  - Connection failure simulation
  - UI state recovery
  - Refresh functionality
  - Error message display

- **Animation Performance**
  - PulsingIcon performance testing
  - State transition smoothness
  - Memory usage during animations
  - Animation completion verification

- **Responsive Design Validation**
  - Small screen adaptation (360x640)
  - Large screen layout (1024x768)
  - Theme switching (light/dark)
  - Component positioning

### Accessibility Tests (`accessibility_test.dart`)
- **WCAG 2.1 AA Compliance**
  - Semantic labels for all interactive elements
  - Screen reader navigation structure
  - Focus indicators and keyboard navigation
  - Color contrast verification

- **Semantic Structure**
  - Proper heading hierarchy
  - Landmark identification
  - Form control labeling
  - Dynamic content announcements

- **Error State Accessibility**
  - Error message announcements
  - Recovery action accessibility
  - Troubleshooting dialog navigation
  - Help content structure

- **Touch Target Validation**
  - Minimum size requirements (48x48dp)
  - Button accessibility
  - Focus management
  - Gesture recognition

## Running Tests

### All Tests
```bash
flutter test
```

### Specific Test Files
```bash
flutter test test/widget_test.dart
flutter test test/integration_test.dart
flutter test test/accessibility_test.dart
```

### Coverage Report
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Test Coverage Areas

### Component Coverage
- ✅ ConnectionStatusBanner (all states and transitions)
- ✅ PulsingIcon (active/inactive animations)
- ✅ Main application flow
- ✅ Settings navigation
- ✅ Error dialogs and recovery
- ✅ Form validation and input handling

### State Coverage
- ✅ Connected/disconnected states
- ✅ Error states with retry functionality
- ✅ Loading states with progress indicators
- ✅ Animation start/stop states
- ✅ Theme switching (light/dark)
- ✅ Screen size adaptations

### Accessibility Coverage
- ✅ Semantic labels and descriptions
- ✅ Screen reader navigation
- ✅ Keyboard navigation and shortcuts
- ✅ Focus management and indicators
- ✅ Color contrast compliance
- ✅ Touch target requirements
- ✅ Error state announcements

### Animation Coverage
- ✅ ConnectionStatusBanner fade/slide transitions
- ✅ PulsingIcon scale and glow effects
- ✅ Transfer progress bar animations
- ✅ Peer list item animations
- ✅ State change transitions
- ✅ Animation performance validation

## Test Utilities and Helpers

### Custom Matchers
- `findsOneWidget` - Verifies single widget existence
- `findsNothing` - Verifies widget absence
- `findsWidgets` - Verifies multiple widget existence

### Semantic Testing
- Widget predicate matching for Semantics properties
- Label and hint validation
- Accessibility property verification

### Animation Testing
- `pumpAndSettle()` - Waits for all animations to complete
- `pump()` - Advances single frame
- Animation controller state verification

## Golden File Testing (Future Enhancement)

Golden file tests will be added to ensure consistent visual appearance across:
- Different screen sizes
- Theme variations
- Component states
- Animation frames

To generate golden files:
```bash
flutter test --update-goldens
```

## Performance Testing

The test suite includes performance validation for:
- Animation frame rates
- Memory usage during state changes
- Widget rebuild efficiency
- Gesture response times

## Continuous Integration

These tests are designed to run in CI/CD pipelines with:
- Automated test execution
- Coverage reporting
- Performance regression detection
- Accessibility compliance verification

## Test Data and Mocking

The tests use:
- Predefined IP addresses for connection testing
- Mock error messages for error state testing
- Simulated user interactions
- Controlled animation timing

## Debugging Test Failures

Common debugging approaches:
1. Use `tester.binding.debugPrintRebuildDirtyWidgets()` for widget tree issues
2. Add `await tester.pump(Duration(seconds: 1))` to slow down test execution
3. Use `find.byType()` when `find.text()` fails due to styling
4. Verify animation completion with `tester.binding.hasScheduledFrame`

## Maintenance

- Update tests when UI components change
- Add new tests for new features
- Maintain test performance as app grows
- Keep accessibility tests current with WCAG updates
- Review and update golden files regularly

---

This testing suite ensures LibreDrop's UI remains robust, accessible, and performant across all supported platforms and use cases.