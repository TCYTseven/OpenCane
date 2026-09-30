# OpenCane privacy policy

OpenCane is an iPhone app that helps blind and low-vision people walk with a white cane. It is
built so that the parts that keep you safe work on the phone alone. This page lists every way
information can leave your phone, and which of them you control.

## What stays on your phone

- **Camera and LiDAR.** Obstacle detection, head-height warnings, drop-off warnings and sign
  reading run on the phone. Camera frames are not stored or uploaded for these features.
- **Location.** Your position is used on the phone to guide you along a route. When you search
  for a destination, Apple Maps receives the text you type and your approximate position, as it
  does for any app that uses Apple's map search.
- **Trip logs.** If "Write trip log" is on, a log of each walk is saved in the app's folder in the
  Files app. It is not uploaded. You can delete it there.
- **Health data.** OpenCane reads your step count from Apple Health for the arrival summary. It
  does not write to Health. The step count leaves the phone only inside a walk summary, and only
  while **Share data with OpenCane cloud** is on (see below).
- **Voice commands.** Speech recognition uses Apple's speech recognizer: on the phone when the
  phone supports it, otherwise Apple's servers.

## What can leave your phone, and when

Each of these is either off by default or needs a service key that the person who built your copy
of the app added. OpenCane does not sell data or use it for advertising.

| What | Sent to | When |
|---|---|---|
| A photo from the camera | The cloud vision service configured in this build (for example Anthropic, Google Gemini or OpenAI) | When you ask "Where am I", or while **Hazard watch** is on during a route. Without a configured service, both run on the phone. |
| What you ask by voice, sometimes with a camera photo | The same cloud model | When you ask a question the phone cannot answer by itself |
| The text of lines OpenCane speaks | ElevenLabs, to produce the natural voice | When the natural voice is set up and turned on. Without it, the iPhone voice is used. |
| Cane events and your position | The OpenCane alert service (a Grok Bot routine), which may email or text the family contacts you entered. With **Add a short summary** on, the event's facts also go to the configured cloud text model, which writes one sentence for your family. | Only while **Alert my family** is on (OpenCane Premium) |
| Family email addresses | The OpenCane alert service | When you tap **Save family emails** |
| Medical ID, family contacts, walk summaries (with start and end points, distance and step count), hazard photos, family-alert events, and a random install ID | The OpenCane cloud (Supabase) | Only while **Share data with OpenCane cloud** is on (Profile tab). Off by default. |
| Purchase history and an anonymous app user ID | RevenueCat, which manages the OpenCane Premium subscription | When the app starts, and when you subscribe or restore. Payment itself is handled by Apple; OpenCane never sees your card. |

## Your choices

- Every optional feature above can be turned off in the app, and turning it off stops future
  uploads.
- Camera, location and microphone access can be changed at any time in the iPhone Settings app.
- Emergency calling, obstacle detection and navigation work without any of the optional services.

## Children

OpenCane is not directed at children under 13 and does not knowingly collect their information.

## Contact

OpenCane is an open-source project. Questions or requests about your data: open an issue at
<https://github.com/TCYTseven/OpenCane/issues>.
