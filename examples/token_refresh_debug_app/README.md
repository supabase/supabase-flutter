# Token Refresh Debug App

This is a diagnostic application designed to help reproduce and debug the intermittent token refresh issue reported in [Issue #1158](https://github.com/supabase/supabase-flutter/issues/1158).

## Problem Description

Users are experiencing inconsistent token refresh behavior where:
- Sometimes auto-refresh works correctly
- Sometimes the SDK emits a `signedOut` event instead of refreshing expired tokens
- This results in 403 errors and unexpected user logouts
- The issue is intermittent and difficult to reproduce

## Purpose

This app provides:
1. **Real-time session monitoring** - View token expiry status, time remaining, and session details
2. **Comprehensive logging** - All instrumentation logs from the SDK are displayed in the console
3. **App lifecycle tracking** - Monitor app state changes (paused/resumed)
4. **Manual testing tools** - Trigger API calls and manual token refreshes
5. **Reproduction environment** - Controlled conditions to reproduce the issue

## Setup

### Prerequisites

1. A Supabase project with authentication enabled
2. Configure your project with a short token expiry for easier testing:
   - Go to your Supabase Dashboard
   - Navigate to Authentication > Settings
   - Set "JWT expiry limit" to a short duration (e.g., 300 seconds = 5 minutes)
   - This allows you to reproduce the issue faster without waiting hours

3. Create a test user in your project
4. Optional: Create a `test_table` for API testing (not required)

### Installation

```bash
cd examples/token_refresh_debug_app
flutter pub get
flutter run
```

## Usage

### Step 1: Configure Supabase

1. Launch the app
2. Enter your Supabase URL (e.g., `https://your-project.supabase.co`)
3. Enter your Supabase Anon Key
4. Click "Initialize"

### Step 2: Sign In

1. Enter your test user email
2. Enter password
3. Click "Sign In"

### Step 3: Monitor Session

Once signed in, you'll see the Debug Dashboard with:

- **Session Status Card** (Green/Red)
  - Current session state (Active or EXPIRED)
  - User ID and email
  - Token expiry time
  - Time remaining until expiry
  - Access token preview
  - Refresh token availability

- **Controls**
  - Test API Call - Makes a query to test if token is valid
  - Manual Token Refresh - Manually triggers a refresh
  - Sign Out - Logs out the user
  - App State indicator

- **Event Log**
  - Shows auth state changes (signedIn, tokenRefreshed, signedOut)
  - Shows app lifecycle changes (resumed, paused, inactive)
  - Timestamped for correlation with console logs

### Step 4: Reproduce the Issue

#### Method 1: App Pause/Resume with Expired Token

1. **Note the expiry time** - Check "Time Until Expiry"
2. **Minimize the app** - Use your device/simulator to background the app
3. **Wait for token to expire** - Wait longer than the expiry time
4. **Resume the app** - Bring the app back to foreground
5. **Observe behavior**:
   - ✅ **Expected**: Session status stays green, "Time Until Expiry" resets (token was refreshed)
   - ❌ **Bug**: Session disappears or shows "No active session" (signedOut event was emitted)

#### Method 2: Network Interruption

1. **Enable airplane mode** while token is about to expire
2. **Wait for auto-refresh to trigger**
3. **Re-enable network**
4. **Observe** if session is preserved or user is signed out

#### Method 3: Rapid Lifecycle Changes

1. **Rapidly pause and resume** the app multiple times
2. **Check** if session remains stable
3. **Look for** race conditions in the logs

### Step 5: Analyze Logs

The app outputs comprehensive logs to the console showing:

```
INFO: 14:23:45.123: supabase.supabase_flutter: App lifecycle state changed to: resumed
FINE: 14:23:45.124: supabase.auth: Starting auto refresh with session state: expiresAt=2024-01-20T14:28:45.000Z, isExpired=false, hasRefreshToken=true
FINE: 14:23:45.125: supabase.auth: Auto-refresh tick: expires in 58 ticks (583s), threshold=3
INFO: 14:23:45.126: supabase.supabase_flutter: Starting session recovery from local storage
```

Key things to look for:
- **Session recovery timing** - Does it complete before auto-refresh starts?
- **Auto-refresh tick calculations** - Are expiry times calculated correctly?
- **Error messages** - What type of errors occur during refresh?
- **SignedOut events** - When do they occur and why?
- **App lifecycle timing** - Do rapid state changes cause issues?

## Expected Log Flow (Successful Refresh)

```
1. App resumed
2. Auto-refresh timer starts
3. Session recovery starts
4. Session recovery completes
5. Auto-refresh tick checks expiry
6. Token refresh triggered (when threshold reached)
7. Token refresh successful
8. tokenRefreshed event emitted
9. Session persisted to storage
```

## Problematic Log Flow (Issue Reproduces)

```
1. App resumed
2. Auto-refresh timer starts
3. Auto-refresh tick runs immediately
4. Session recovery still in progress (race condition)
5. Token refresh fails (various reasons)
6. signedOut event emitted
7. Session cleared
8. User unexpectedly logged out
```

## Key Scenarios to Test

### Scenario 1: Clean Resume After Expiry
- Start: Valid session
- Action: Pause app for >expiry duration
- Resume: Should auto-refresh
- Check: Session stays active

### Scenario 2: Network Error During Refresh
- Start: Token about to expire
- Action: Enable airplane mode
- Wait: Trigger auto-refresh attempt
- Resume: Re-enable network
- Check: Session preserved, retries refresh

### Scenario 3: Concurrent Refresh Attempts
- Start: Token about to expire
- Action: Rapidly open/close app
- Check: Only one refresh call made
- Check: No race conditions

### Scenario 4: Custom Storage Implementation
- Configure: Use FlutterSecureStorage instead of SharedPreferences
- Run: All above scenarios
- Check: Same behavior as default storage

## Troubleshooting

### Issue: "No active session" shows immediately after resume
- This indicates the session was not properly restored from storage
- Check logs for storage read errors
- Verify permissions for SharedPreferences/FlutterSecureStorage

### Issue: Token refresh fails with 401
- Check if refresh token is still valid
- Verify Supabase project settings allow token refresh
- Check if user was deleted/disabled

### Issue: Token refresh fails with network error
- Verify internet connectivity
- Check Supabase project status
- Look for retryable vs non-retryable errors in logs

### Issue: App doesn't respond to lifecycle changes
- Verify WidgetsBindingObserver is properly registered
- Check if auto-refresh is enabled in configuration
- Look for timer start/stop logs

## Configuration Options

You can modify the app to test different scenarios:

### Change Log Level
In `main.dart`, adjust logging level:
```dart
Logger.root.level = Level.ALL;     // Most verbose
Logger.root.level = Level.FINE;    // Debug info
Logger.root.level = Level.INFO;    // Important events only
```

### Test with Different Storage
Swap SharedPreferences for FlutterSecureStorage:
```dart
await Supabase.initialize(
  url: url,
  anonKey: anonKey,
  authOptions: FlutterAuthClientOptions(
    localStorage: MyCustomSecureStorage(), // Your implementation
  ),
);
```

### Adjust Auto-Refresh Timing
The timing constants are in `packages/gotrue/lib/src/constants.dart`:
- `autoRefreshTickDuration` - How often to check (default: 10 seconds)
- `autoRefreshTickThreshold` - When to refresh (default: 3 ticks before expiry)
- `expiryMargin` - Safety buffer (default: 30 seconds)

## Contributing Findings

When reporting results:

1. **Include console logs** - Copy relevant log sections
2. **Describe the scenario** - Which test case you ran
3. **Note timing** - How long after pause did you resume?
4. **Environment details** - iOS/Android version, Flutter version
5. **Storage type** - Default or custom implementation
6. **Consistency** - How often does it reproduce (1/10, 5/10, always)?

## Technical Details

### Instrumentation Added

This app uses the instrumentation added to the SDK:
- **gotrue_client.dart** - Token refresh lifecycle
- **supabase_auth.dart** - App lifecycle and recovery
- **session.dart** - Expiry calculations
- **local_storage.dart** - Storage operations
- **supabase.dart** - Initialization flow

### Dependencies

- `supabase_flutter` - Local path to repository version with instrumentation
- `logging` - For structured log output
- `intl` - For timestamp formatting

## Next Steps

After reproducing the issue with this app:

1. Share logs with the Supabase team
2. Help identify the specific timing conditions that trigger the bug
3. Test proposed fixes
4. Verify the fix resolves the issue in your production app

## Related Issues

- [Issue #1158](https://github.com/supabase/supabase-flutter/issues/1158) - Original bug report
