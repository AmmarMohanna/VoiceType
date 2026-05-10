# VoiceType

A minimal macOS menu-bar dictation app.

## Background workflow

VoiceType is designed to stay out of the way. Launch it once and it lives in the macOS menu bar while you work in any app.

Press `Option-Space` from anywhere to start recording, speak naturally, then press `Option-Space` again to stop. VoiceType transcribes in the background and copies the final text to your clipboard automatically.

That keeps the flow simple: shortcut, speak, stop, paste.

## MVP behavior

- Menu-bar app with Start, Stop, Copy, and Settings.
- Option-Space toggles recording.
- Final transcript is copied to the clipboard when recording stops.
- Settings include Fast, Accurate, and Polished modes.
- Arabizi tab uses Yamli for live Lebanese/Arabic transliteration, falls back to an OpenAI model if Yamli is unavailable, and includes an optional stronger "Improve with LLM" pass.
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
ARABIZI_MODEL=gpt-5.4-mini
ARABIZI_IMPROVE_MODEL=gpt-5.4
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
