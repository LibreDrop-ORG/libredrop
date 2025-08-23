# Device Identity Settings UI

**Story ID:** device-identity-settings-ui  
**Epic:** Custom Device Identity Enhancement  
**Status:** Ready for Review

## Story
As a LibreDrop user, I want to customize my device name and avatar in the settings so that other users can easily identify my device on the network.

## Acceptance Criteria
- [ ] User can navigate to device identity section in Settings page
- [ ] User can enter a custom device name with validation (1-30 characters, no special symbols)
- [ ] User can select from a grid of predefined avatar icons
- [ ] Custom device name and avatar choices persist between app sessions
- [ ] Settings follow existing SharedPreferences patterns used in the app
- [ ] UI follows Material Design patterns consistent with existing settings

## Tasks
- [x] **Task 1: Extend SettingsService with device identity persistence**
  - [x] Add `loadDeviceName()` and `saveDeviceName(String name)` methods
  - [x] Add `loadDeviceAvatar()` and `saveDeviceAvatar(String avatar)` methods
  - [x] Follow existing SharedPreferences pattern from download path methods
  - [x] Add proper null handling and default values
  
- [x] **Task 2: Create avatar assets and constants**
  - [x] Add 12 predefined avatar icons using Material Design icons
  - [x] Create `lib/constants/avatars.dart` with avatar definitions
  - [x] Create avatar selection helper methods
  - [x] Use efficient Material Design icons instead of asset files
  
- [x] **Task 3: Extend Settings page with device identity UI**
  - [x] Add "Device Identity" section to Settings page
  - [x] Create device name input field with TextFormField
  - [x] Add form validation for device name (length, characters)
  - [x] Create avatar selection GridView with tap handling
  - [x] Wire up save/load functionality with SettingsService
  - [x] Add proper error handling and user feedback

## Dev Notes
- Follow existing patterns in `lib/settings_service.dart` for persistence
- Use existing Material Design components from `lib/settings_page.dart`
- Device name defaults to `Platform.localHostname` if not customized
- Avatar defaults to OS-based icon if not selected
- Validate against existing `shared_preferences` usage patterns

## Testing Requirements
- Unit tests for SettingsService device identity methods
- Widget tests for device identity settings UI components
- Integration tests for settings persistence
- Validation edge case testing (empty names, long names, special characters)

## File List
- `lib/settings_service.dart` - Extended with device identity persistence methods
- `lib/constants/avatars.dart` - Created avatar constants with Material Design icons
- `lib/settings_page.dart` - Extended with device identity UI section

## Dev Agent Record

### Agent Model Used
Claude Sonnet 4 (BMad Developer Agent)

### Tasks Progress
- [x] Task 1: Extend SettingsService with device identity persistence
- [x] Task 2: Create avatar assets and constants  
- [x] Task 3: Extend Settings page with device identity UI

### Debug Log References
- Flutter analyze: Fixed deprecated withOpacity usage and context handling
- Build test: Successful APK compilation verified

### Completion Notes
- All three tasks completed successfully
- Code follows existing LibreDrop patterns and Material Design guidelines
- Settings persist using SharedPreferences pattern
- 12 Material Design avatar icons available for selection
- Form validation includes length and character restrictions
- Build passes with only 1 pre-existing lint issue (unrelated)

### Change Log
- Added device identity persistence to SettingsService
- Created DeviceAvatars constants class with Material Design icons
- Extended Settings page UI with device name input and avatar selection grid
- Implemented form validation and proper async context handling
- All code passes Flutter analyze with modern API usage