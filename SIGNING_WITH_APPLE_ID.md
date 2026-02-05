# Code Signing with Apple Developer ID

## 1. Get Apple Developer Account
1. Go to https://developer.apple.com/programs/
2. Enroll ($99/year)
3. Wait for approval (usually 24-48 hours)

## 2. Create Developer ID Certificate
1. Go to https://developer.apple.com/account/resources/certificates/list
2. Click "+" to create new certificate
3. Select "Developer ID Application"
4. Follow instructions to generate Certificate Signing Request (CSR)
5. Download and install the certificate

## 3. Update project.yml
```yaml
targets:
  WhisperDictation:
    settings:
      CODE_SIGN_IDENTITY: "Developer ID Application: Your Name (TEAM_ID)"
      DEVELOPMENT_TEAM: YOUR_TEAM_ID
      CODE_SIGN_STYLE: Manual
```

## 4. Build and Sign
```bash
xcodegen generate
xcodebuild -project WhisperDictation.xcodeproj \
  -scheme WhisperDictation \
  -configuration Release \
  clean build \
  CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
```

## 5. Notarize (Optional but Recommended)
```bash
# Create app bundle zip
ditto -c -k --keepParent /Applications/WhisperDictation.app WhisperDictation.zip

# Submit for notarization
xcrun notarytool submit WhisperDictation.zip \
  --apple-id "your@email.com" \
  --team-id YOUR_TEAM_ID \
  --password "app-specific-password"

# Wait for approval (usually 5-15 minutes)

# Staple the notarization ticket
xcrun stapler staple /Applications/WhisperDictation.app

# Verify
spctl -a -vv /Applications/WhisperDictation.app
```

## 6. Package for Release
```bash
cd /Applications
zip -r ~/Desktop/WhisperDictation-v1.0-signed.zip WhisperDictation.app
```

Done! Users can now open the app without warnings.
