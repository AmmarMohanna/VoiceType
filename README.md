# VoiceType

A minimal macOS menu-bar dictation app.

## MVP behavior

- Menu-bar app with Start, Stop, Copy, and Settings.
- Option-Space toggles recording.
- Final transcript is copied to the clipboard when recording stops.
- Settings include Fast, Accurate, and Polished modes.
- Start at login is implemented with a LaunchAgent for the packaged app.

## API key

The app reads the key in this order:

- macOS Keychain, configured from the app Settings window.
- `OPENAI_API_KEY`, useful while developing from Terminal.
- `AppSecrets.openAIAPIKey`, intentionally blank in source control.

Do not commit a real API key.

## Build

```sh
./Scripts/build-app.sh
open build/VoiceType.app
```

The first launch should prompt for microphone permission.

## Install locally

```sh
./Scripts/install-app.sh
```

Open Settings from the menu-bar gear button, save your OpenAI API key, and enable Start at login.

## Notes

The app does not paste into the active app. It only copies to the clipboard.
