# Facebook Authentication Setup

This guide explains how to set up Facebook authentication in the Supabase Examples app.

## Prerequisites

1. A Facebook Developer account
2. A Facebook App created in the Facebook Developer Console
3. Supabase project with Facebook OAuth configured

## Setup Steps

### 1. Facebook Developer Console Configuration

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app or use an existing one
3. Add "Facebook Login" product to your app
4. Configure your OAuth redirect URIs in Facebook Login settings:
   - Add your Supabase project's Facebook OAuth callback URL
   - Format: `https://[your-project-ref].supabase.co/auth/v1/callback`

### 2. Supabase Configuration

1. Go to your Supabase project dashboard
2. Navigate to Authentication > Providers
3. Enable Facebook provider
4. Enter your Facebook App ID and App Secret
5. Configure the redirect URL if needed

### 3. Flutter App Configuration

#### Android Configuration

The following files have been configured for you:

1. **AndroidManifest.xml** - Contains Facebook SDK configuration
2. **strings.xml** - Contains placeholder values for Facebook credentials

You need to update the following values in `android/app/src/main/res/values/strings.xml`:

```xml
<string name="facebook_app_id">YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<string name="facebook_client_token">YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
<string name="fb_login_protocol_scheme">fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
```

#### iOS Configuration

The following files have been configured for you:

1. **Info.plist** - Contains Facebook SDK configuration

You need to update the following values in `ios/Runner/Info.plist`:

```xml
<key>FacebookAppID</key>
<string>YOUR_ACTUAL_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
```

And update the URL scheme:
```xml
<string>fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
```

## Getting Your Facebook Credentials

### App ID
1. Go to Facebook Developers Console
2. Select your app
3. Go to Settings > Basic
4. Copy the "App ID"

### Client Token
1. In the same Basic settings page
2. Copy the "Client Token"
3. If you don't see it, you may need to generate one

## Testing

1. Replace all placeholder values with your actual Facebook credentials
2. Run `flutter pub get` to install dependencies
3. Run the app and test the "Continue with Facebook" button
4. Ensure your Facebook app is configured to allow the bundle ID/package name of your Flutter app

## Troubleshooting

- **Android**: Make sure your package name in `android/app/build.gradle` matches what's configured in Facebook
- **iOS**: Make sure your bundle identifier matches what's configured in Facebook  
- **Both platforms**: Ensure your Facebook app is not in "Development Mode" if testing with non-developer accounts
- Check that your Supabase Facebook OAuth configuration matches your Facebook app settings

## Security Notes

- Never commit real Facebook credentials to version control
- Consider using environment variables or secure configuration management
- Regularly rotate your Facebook Client Token