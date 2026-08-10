# Apple Delete Note Design

## Context

Account deletion currently shows the Apple manual revoke note whenever the Edge Function returns `appleRevoked: false`. That happens for every successful deletion, including Google and login/password accounts, so non-Apple users see irrelevant Apple text.

## Goal

Show the Apple manual revoke note only when the deleted account was signed in through Apple.

## Design

Before calling the `delete-account` Edge Function, the Flutter account deletion service reads the current Supabase user's auth provider from client auth metadata. If the provider is `apple`, the deletion result carries a UI flag telling `AccountSection` to show the Apple manual revoke note after success. If the provider is not Apple, or provider metadata is missing, the UI shows only the normal deletion success message.

The Edge Function contract stays unchanged. `appleRevoked` remains available for future server-side token revocation support, but it no longer causes every user to see Apple-specific guidance.

## Testing

Add focused service tests for Apple and non-Apple provider metadata. Update the widget tests so a successful non-Apple deletion does not show the Apple note, while an Apple deletion still does.
