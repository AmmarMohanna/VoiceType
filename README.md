# VoiceType

A minimal macOS menu-bar dictation app.

## MVP behavior

- Menu-bar app with Start, Stop, Copy, and Settings.
- Option-Space toggles recording.
- Final transcript is copied to the clipboard when recording stops.
- Settings include Fast, Accurate, and Polished modes.
- Arabizi tab converts Latin/Arabizi text like `kifak`, `3arabi`, and `7abibi` into Arabic text, then refines it with a fast OpenAI model when available.
- Start at login is implemented with a LaunchAgent for the packaged app.

## API key

The app reads the key in this order:

- `OPENAI_API_KEY`, useful while developing from Terminal.
- `.env` bundled into the local app by `Scripts/build-app.sh`.
- `.env` in the current directory when running from Terminal.
- `~/.voicetype/.env`, useful if you want one shared local config.
- `AppSecrets.openAIAPIKey`, intentionally blank in source control.

Create a local `.env` file:

```sh
cp .env.example .env
```

Then edit `.env`:

```env
OPENAI_API_KEY=sk-...
ARABIZI_MODEL=gpt-5.4-nano
```

`.env` is ignored by Git and is copied into the local app bundle during build.

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
