# Doble Parsi for iOS

Status: planning only. No iOS application or installable IPA exists yet.

## Agreed direction

Build an iPhone app with an internal media player, Gemini Live dubbing, captions, export, Persian and English UI, and a cloud macOS build. Install for personal use from Windows using a compatible sideloading tool and the user's Apple account. Free provisioning and renewal are subject to Apple's current limitations.

## Platform boundaries

The Android application captures other applications' playback using MediaProjection. iOS does not offer a directly equivalent general-purpose API. A floating overlay across arbitrary apps and other apps' media metadata are also unavailable through equivalent public APIs. ReplayKit broadcast capture must be validated separately on real devices and cannot be assumed to capture protected content or all applications.

## Existing protocol

The Android GeminiLiveClient connects to BidiGenerateContent over WebSocket, sends mono PCM16 at 16 kHz, receives mono PCM16 at 24 kHz, requests audio translation and optional transcripts, and processes usage metadata. The implementation must preserve connection, interruption, quota, and session lifecycle behavior.

## Remaining work

- Design and implement the media decoding, real-time pacing, translation, playback and synchronization pipeline.
- Implement captions, audio export, language and settings UI, usage accounting and secure key storage.
- Create the iOS project, automated macOS build and unsigned artifact; document Windows signing and installation.
- Build on macOS and test with a real Gemini key and physical iPhone before claiming feature parity or installability.

## Initial iOS scaffold

The initial SwiftUI screen imports and plays a user-selected local audio or video file. Live dubbing, captions, export, usage metering and settings are not implemented. The GitHub Actions workflow generates an Xcode project and builds an unsigned IPA; the artifact is not directly installable until signed. The pipeline and playback need validation on GitHub Actions and an iPhone.
