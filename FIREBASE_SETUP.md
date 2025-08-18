# Firebase Setup Instructions

## The authentication error you're seeing is because Firebase Authentication needs to be enabled in the Firebase Console.

### Steps to fix the CONFIGURATION_NOT_FOUND error:

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: `skoro-17721`
3. **Enable Authentication**:
   - Click on "Authentication" in the left sidebar
   - Click on "Get started" if you haven't set it up yet
   - Go to the "Sign-in method" tab
   - Enable "Email/Password" authentication:
     - Click on "Email/Password"
     - Toggle "Enable" to ON
     - Click "Save"

4. **Optional - Enable additional sign-in methods** if needed:
   - Google Sign-in
   - Phone authentication
   - Anonymous authentication

### After enabling Authentication:

1. The app should work properly
2. You can create accounts and sign in
3. User data will be stored in Firestore

### Current Project Configuration:
- Project ID: `skoro-17721`
- Package Name: `com.harikiruthik.skoro`
- Firebase configuration file: `lib/firebase_options.dart` ✅ (Generated)
- Google Services: `android/app/google-services.json` ✅ (Configured)

### Test the fix:
1. After enabling Authentication in Firebase Console
2. Try creating an account again in the app
3. The "CONFIGURATION_NOT_FOUND" error should be resolved

---

**Note**: The Firebase configuration file has been properly generated and the app has been updated to use it. The only remaining step is to enable Authentication in the Firebase Console.
