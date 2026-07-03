# MyWhisper — User Guide

A complete, plain-English guide to using MyWhisper: a menu-bar app that lets
you dictate text with a hotkey and have it typed into whatever app you're
using, entirely on your own Mac. No account, no cloud, no subscription.

---

## 1. Install

1. Open the **`MyWhisper-<version>.dmg`** file you downloaded, and drag
   **MyWhisper.app** into your **Applications** folder.
2. Open **MyWhisper.app** (double-click it in Applications, or in the DMG).
   Because this free build isn't notarized by Apple (notarization needs a
   paid Apple Developer account, which this project doesn't have yet), macOS
   will refuse to open it the first time and show a warning that says
   **""MyWhisper.app" Not Opened — Apple could not verify "MyWhisper.app"
   is free of malware"**, offering only two buttons: **Move to Trash** and
   **Done**. This doesn't mean anything is wrong with the app — it's just
   Apple's standard warning for any app that isn't distributed through the
   App Store or a paid developer certificate. To open it anyway:
   - Click **Done** — do NOT click "Move to Trash".
   - Go to **System Settings → Privacy & Security**.
   - Scroll all the way down — you'll see a line like *"MyWhisper.app was
     blocked to protect your Mac"* with an **Open Anyway** button.
   - Click **Open Anyway**, then confirm in the dialog that appears (macOS
     may ask for your password or Touch ID).
   - You only do this once — from then on the app opens normally.
3. MyWhisper's icon (a small waveform) appears in your menu bar, top-right of
   the screen. **It works immediately** — a small starter speech model is
   bundled inside the app, so you can dictate right away without downloading
   anything.
4. Grant the two permissions MyWhisper asks for (a first-run wizard also
   walks you through this — see [section 3](#3-the-setup-assistant)):
   - **Microphone** — so it can hear you. System Settings →
     **Privacy & Security → Microphone**.
   - **Accessibility** — so it can type/paste text into other apps for you.
     System Settings → **Privacy & Security → Accessibility**. Without this,
     MyWhisper still copies your dictated text to the clipboard — you'd just
     need to paste it yourself with ⌘V.

That's it. Tap **⌥Space** (Option + Space) anywhere and start talking.

---

## 2. Your first dictation

### Tap vs. hold

The dictation hotkey (⌥Space by default, changeable — see
[section 5](#5-settings-window-)) works two ways:

- **Tap it once** — recording starts. Tap it again to stop, transcribe, and
  paste.
- **Press and hold it** — recording starts and continues only while you keep
  the key held down; releasing it stops and transcribes. This only kicks in
  if you hold past **0.35 seconds** — a quick tap-and-release is treated as
  the "tap" behavior above, not an instant stop.

### The recording pill

While recording, a floating pill appears near the bottom-center of your
screen. It shows:

- **Level bars** — five bars that react to your voice volume in real time,
  so you can see the mic is picking you up.
- **Elapsed time** — a running clock (`0:07`, `1:23`, …) so you know how long
  you've been recording.
- **Caption** — the active language and AI mode for this dictation (e.g.
  "English" or "Indonesian · Email"), reflecting any per-app profile that
  matched the frontmost app (see [section 7](#per-app-profiles)).
- **Live partial text** (if Live Preview is on) — a running, best-effort
  transcript of what you've said so far, updated roughly every second and
  a half.
- **A ✕ button** — click it to cancel the recording outright: nothing is
  transcribed, nothing is pasted, nothing is saved to history.

The pill is borderless and floats above other windows without stealing
keyboard focus from whatever you're working in.

### Esc to cancel

While recording, pressing **Esc** cancels the dictation the same way the ✕
button does — discarding the audio with no transcription or paste. Esc only
has this effect while a recording is in progress; the rest of the time it
behaves completely normally system-wide, so it won't interfere with any
other app.

### Where the text goes

Once you stop, MyWhisper transcribes the audio locally and, if Accessibility
access is granted, pastes the result directly into whatever text field was
focused before you started dictating (using a synthetic ⌘V). If Accessibility
isn't granted, the text is instead copied to your clipboard and you'll see a
notification asking you to paste manually with ⌘V.

### Clipboard restore

MyWhisper is careful not to clobber your clipboard: before pasting, it
remembers whatever text you had previously copied, and about one second
after pasting the dictated text, it restores your old clipboard contents
(as long as nothing else has overwritten the clipboard in the meantime).

---

## 3. The Setup Assistant

MyWhisper shows a first-run wizard automatically the very first time you
launch it. You can reopen it anytime from the menu bar: **MyWhisper icon →
Setup Assistant…**.

The window has four sections:

### Permissions

Two rows, each showing live status:

- **Microphone** — shows "✅ Granted" or "⚠️ Not granted" with a **Grant…**
  button. If macOS hasn't asked you yet, clicking it triggers the standard
  system prompt. If you previously denied it, clicking it instead opens
  **System Settings → Privacy & Security → Microphone** directly, since macOS
  won't re-prompt automatically once denied.
- **Accessibility** — same idea, with an **Open System Settings…** button
  that takes you straight to **Privacy & Security → Accessibility** and also
  re-triggers the system's Accessibility permission prompt.

Both rows refresh automatically about once a second while the window is
open, so granting a permission in System Settings updates the wizard
immediately — no need to close and reopen it.

### Speech model

Shows one of three states:

- **"✅ Starter model included (small)…"** — you're already set up with the
  small model bundled inside the app, with a **Download** button to get the
  larger, more accurate `large-v3-turbo` model (~1.5 GB, one-time).
- **"✅ Model ready: `<name>`"** — you've already downloaded a full model;
  nothing more to do here.
- **"Download the recommended model (large-v3-turbo, ~1.5 GB, one time)"** —
  no model at all yet (a bare/dev build with no bundled starter); click
  **Download**.

Clicking **Download** shows a progress bar and a byte counter (e.g. "512 MB
of 1.5 GB"), plus a **Cancel** button. The model downloads from Hugging Face
— the only non-localhost network request the app makes automatically when
you ask it to (see [section 13](#13-where-your-data-lives)).

### AI modes (optional)

Explains that AI modes rewrite your dictation (e.g. into a polished email)
using a **local** AI model served by [Ollama](https://ollama.com) — entirely
optional, and everything else in the app works without it. This section
walks you through it with no terminal required, showing one of three live
states (re-checked roughly every 3 seconds):

1. **"○ Ollama not installed (or not running)"** — a **Get Ollama ↗** button
   opens `ollama.com/download` in your default browser (this is the *only*
   thing that ever opens `ollama.com` — MyWhisper itself never fetches that
   URL). Install and launch Ollama like any other Mac app; the wizard
   detects it automatically once it's running, no restart needed.
2. **"◐ Ollama is running — needs an AI model"** — a **Download AI Model
   (~2 GB)** button pulls a chat model (`llama3.2` by default) directly
   through your local Ollama, with a live progress bar and byte counter.
   This download is performed by Ollama itself on your Mac, not fetched by
   MyWhisper from the internet.
3. **"✅ AI modes ready (`<model>`) — pick a mode from the menu bar (e.g.
   Email)."** — you're done; open the **Mode** submenu in the menu bar and
   pick one.

If a pull fails, the error message appears in red under the buttons.

### Try it

A small text box you can click into, type a placeholder cue into
("Click here, press ⌥Space and speak — your words will appear."), then press
your hotkey and dictate — proving the whole pipeline end to end before you
close the wizard. Below it, a status line shows live engine status (e.g.
"Loading model…", "Ready — dictate away!") whenever this window is open.

### Reopening it later

**MyWhisper icon (menu bar) → Setup Assistant…** — any time, as many times
as you like. Clicking **Done** just marks first-run onboarding as complete
(so it won't auto-open again) and closes the window; it doesn't lock
anything in.

---

## 4. Every menu item, one by one

Click the waveform icon in the menu bar. From top to bottom:

1. **Status line** (not clickable) — shows what's happening right now:
   "Ready — `<model name>`", "Recording…", "Transcribing…", a loading
   message, or an error.
2. **Start Dictation (⌥Space)** / **Stop & Transcribe (⌥Space)** — toggles
   recording, identical to tapping the hotkey. Grayed out while loading or
   transcribing so you can't start a second overlapping recording.
3. **Cancel Dictation (Esc)** — appears only while recording; same as
   pressing Esc or the pill's ✕.
4. **Language** — a submenu listing every supported language (see
   [section 6](#6-languages)) with a checkmark next to the active one.
   Selecting one applies immediately, for the next dictation onward.
5. **Model** — a submenu listing every model you've downloaded into
   `~/Library/Application Support/MyWhisper/models/`, checkmarked at the
   active one; selecting a different one restarts the transcription engine
   against it. **Open Models Folder** at the bottom opens that folder in
   Finder. If you have no models downloaded, shows "No models downloaded".
6. **Engine** — *Server (subprocess)* (default) or *In-Process
   (experimental)* — see [ARCHITECTURE.md](ARCHITECTURE.md) for what these
   mean internally. Switching restarts the engine.
7. **Mode** — *Raw* (no AI rewriting, the default) plus every mode defined
   in `modes.json` (see [section 8](#8-ai-modes)). **Edit Modes…** at the
   bottom opens `modes.json` in your default text/JSON editor.
8. **Change Hotkey… (now `<hotkey>`)** — opens a small floating window;
   press any key combination (must include a modifier — ⌘⌥⌃⇧ — or be an
   F-key) and it's captured and applied immediately. Esc in that window
   cancels without changing anything.
9. **History…** — opens the dictation history window (see
   [section 11](#11-history)).
10. **Transcribe Audio File…** — opens a file picker to transcribe an
    existing audio file rather than live speech (see
    [section 10](#10-transcribing-audio-files)).
11. **Edit Text Replacements…** — opens `replacements.json` (vocabulary +
    find/replace rules — see [section 9](#9-teaching-it-your-words)) in your
    default editor. Creates the file with a starter example first, if it
    doesn't exist yet.
12. **Edit App Profiles…** — opens `profiles.json` (per-app overrides — see
    [section 7](#per-app-profiles)) the same way.
13. **Sound Cues** (checkbox, default on) — plays a short sound when
    recording starts, stops, or is cancelled.
14. **Auto-Stop After Silence** (checkbox, default off) — automatically ends
    recording after you go quiet for about two seconds, so you don't have to
    tap the hotkey again to stop.
15. **Voice Commands** (checkbox, default on) — recognizes short spoken
    commands like "scratch that" instead of pasting them literally (see
    [section 7](#voice-commands)).
16. **Spoken Punctuation** (checkbox, default off) — turns spoken words like
    "comma" or "titik" into actual punctuation marks (see
    [section 7](#spoken-punctuation)).
17. **Live Preview** (checkbox, default on) — shows the running partial
    transcript in the recording pill while you speak. Turning this off also
    disables Instant Paste (section 7), since instant paste depends on the
    live preview's partial transcript.
18. **Save History** (checkbox, default on) — whether transcriptions get
    written to `history.json`. Turn off if you don't want a record kept.
19. **Translate to English** (checkbox, default off) — instead of
    transcribing verbatim, asks whisper to translate your speech into
    English (see the caveat about `large-v3-turbo` in
    [section 6](#translate-to-english-caveat)).
20. **Launch at Login** (checkbox) — registers MyWhisper to start
    automatically when you log in. Only enabled when running as a proper
    `.app` bundle (not while running from the command line during
    development).
21. **Open Server Log** — opens `whisper-server.log` (see
    [section 13](#13-where-your-data-lives)) in your default text viewer;
    useful when troubleshooting a model or engine problem.
22. **Setup Assistant…** — reopens the wizard from
    [section 3](#3-the-setup-assistant).
23. **Settings… (⌘,)** — opens the Settings window (see
    [section 5](#5-settings-window-)).
24. **Quit MyWhisper (⌘Q)**.

---

## 5. Settings window (⌘,)

Open with **⌘,** from anywhere while MyWhisper is running, or **Settings…**
in the menu. It duplicates most menu-bar toggles in one place, plus a couple
of extras:

- **Dictation hotkey** row — shows the current hotkey with a **Change…**
  button (same capture flow as the menu item).
- **Checkboxes** — Sound cues, Auto-stop after silence, Voice commands,
  Spoken punctuation ("koma" → ,), Live preview while dictating, Translate to
  English, Launch at login, Save history, and **Instant paste (reuse live
  preview)** — the Settings-window name for what section 7 calls "instant
  paste" / "fast finalize".
- **Language** popup — same list as the menu's Language submenu.
- **Model** popup, with a **Download…** button next to it that opens the
  Setup Assistant (so you can grab a new model without leaving Settings).
- **AI mode** popup — same list as the menu's Mode submenu.
- **Ollama model** text field — the chat model name sent to Ollama when a
  mode doesn't specify its own `"model"` (default `llama3.2`). Edits commit
  when you press Return or click away from the field; an empty value is
  rejected and reverted.
- **Open Models Folder** / **Edit Replacements…** / **Edit Modes…** / **Open
  Server Log** buttons — same actions as their menu equivalents.

The window remembers nothing you haven't explicitly changed — reopening it
(or switching back to it) always re-reads current settings, so it can never
show stale state after you've changed something from the menu bar instead.

---

## 6. Languages

Open the **Language** menu (or the Settings window's Language popup) to
choose from:

- **Auto-detect** (default) — whisper guesses the spoken language per
  utterance.
- **Mixed (Indonesian + English)** — for code-switched speech (see below).
- **Mixed (Tagalog + English)**, **Mixed (Hindi + English)**, **Mixed
  (Spanish + English)**, **Mixed (Chinese + English)** — additional
  code-switching packs.
- ~24 fixed languages: English, Indonesian, Chinese, Spanish, French, German,
  Japanese, Korean, Portuguese, Russian, Arabic, Hindi, Italian, Dutch,
  Turkish, Vietnamese, Thai, Malay, Polish, Ukrainian, Swedish, Tagalog, and
  more — whisper's underlying models support roughly 100 languages in total;
  this list is the curated shortcut set in the menu.

### Fixed vs. auto vs. mixed

- A **fixed** language pins whisper's `language` parameter exactly — most
  reliable when you know what you'll be speaking.
- **Auto-detect** lets whisper infer the language per recording; convenient,
  occasionally wrong on very short utterances.
- **Mixed** modes exist because whisper only accepts one `language` value per
  request, so genuinely code-switched speech (e.g. Indonesian sentences with
  English tech jargon mixed in) doesn't have a native "detect both" option.
  Each mixed pack instead pins a primary language (Indonesian, Tagalog,
  Hindi, Spanish, or Chinese) and primes whisper's decoder with a short
  natural-sounding example sentence that itself mixes in English words —
  nudging it to expect and transcribe that pattern correctly rather than
  forcing everything into one language.

### Vocabulary tips for names/jargon

Whichever language you pick, entries you add to `vocabulary` in
`replacements.json` (see [section 9](#9-teaching-it-your-words)) are fed to
whisper as a priming hint alongside the language's own priming text —
this is especially effective for names, product jargon, or acronyms that
whisper would otherwise mishear, and pairs particularly well with Mixed
mode.

### Translate-to-English caveat

The **Translate to English** toggle uses whisper's own translation mode
instead of verbatim transcription. Important: the **`large-v3-turbo`** model
— the one this app recommends and bundles a smaller sibling of — is
distilled specifically for transcription and **cannot translate**. If you
want to use the Translate toggle, switch to `large-v3`, `medium`, or a
smaller model first (see [section 12](#the-cli) and the models table in the
top-level README).

---

## 7. Dictation power features

### Voice commands

When **Voice Commands** is on (default), if your entire dictated utterance —
once cleaned up, and nothing else — matches one of these phrases exactly
(not just contains it), MyWhisper executes the command instead of pasting
the words:

| Phrase (English) | Phrase (Indonesian) | Action |
|---|---|---|
| "scratch that" / "undo that" | "batalkan" / "batalkan itu" | Sends ⌘Z (Undo) to the frontmost app |
| "new line" | "baris baru" | Sends Return once |
| "new paragraph" | "paragraf baru" | Sends Return twice |

Saying, for example, "please scratch that" does **not** trigger the command
— it has to be the whole utterance, so commands never accidentally fire
inside normal dictated sentences. Voice commands require Accessibility
permission to actually send the keystroke; without it, you'll see a
notification asking you to grant it.

Voice-command matching happens **before** spoken punctuation is applied, so
saying just "new paragraph" alone triggers the paragraph-break command
rather than being turned into the literal text "\n\n".

### Spoken punctuation

When **Spoken Punctuation** is on (default off), spoken punctuation words
are replaced with real punctuation marks, and the following word is
automatically capitalized after sentence-ending punctuation or a line break:

| Phrase (English) | Phrase (Indonesian) | Symbol |
|---|---|---|
| "full stop" / "period" | "titik" | `.` |
| "comma" | "koma" | `,` |
| "question mark" | "tanda tanya" | `?` |
| "exclamation mark" | "tanda seru" | `!` |
| "colon" | "titik dua" | `:` |
| "semicolon" | "titik koma" | `;` |
| "new line" | "baris baru" | line break |
| "new paragraph" | "paragraf baru" | blank-line paragraph break |

Multi-word phrases (like "titik dua") are matched before their single-word
counterparts ("titik"), so "titik dua" always becomes `:`, never `.` followed
by stray text. If whisper already produced its own punctuation right next to
a spoken-punctuation token, MyWhisper collapses the duplicate instead of
doubling it up (e.g. "koma, apa" won't become ",, apa"). Capitalization
applies after `.`, `?`, `!`, and both newline tokens.

### Instant paste

**Instant paste** (called "fast finalize" internally; the Settings-window
checkbox is "Instant paste (reuse live preview)", default **on**) makes
dictation feel immediate in the common case: if you stop recording shortly
after the live preview last updated, and the audio recorded since that
preview is short (under about 0.75 seconds) and silent, MyWhisper reuses
that preview's already-transcribed text as your final result instead of
re-transcribing the whole recording from scratch — skipping roughly a
second of wait.

It only kicks in when *all* of the following hold:
- Live Preview is on (instant paste has nothing to reuse without it).
- A preview was actually captured before you stopped.
- The tail of audio after that preview is short and quiet — if you kept
  talking right up to the stop, or your recording exceeds the ~30-second
  preview window, MyWhisper falls back to the normal full re-transcription
  automatically, so you never lose words.

You can turn instant paste off in the Settings window if you'd rather always
get a from-scratch, full-recording transcription.

### Per-app profiles

Per-app profiles let you override language, AI mode, spoken punctuation, or
translation on a **per-application basis** — e.g. always use Message mode
in Slack, or always disable spoken punctuation in Terminal. Open **Edit App
Profiles…** (menu bar or Settings) to edit `profiles.json` directly:

```json
[
  {"app": "Slack", "mode": "Message"},
  {"bundleId": "com.apple.mail", "mode": "Email"},
  {"app": "Terminal", "spokenPunctuation": false}
]
```

Each entry (an object in the JSON array) supports:

| Field | Overrides | Notes |
|---|---|---|
| `app` | — | Matches the frontmost app's display name, case-insensitive, exact match (e.g. `"Slack"`) |
| `bundleId` | — | Matches the frontmost app's bundle identifier, case-insensitive, exact match (e.g. `"com.apple.mail"`) |
| `language` | `Settings.language` | e.g. `"id"`, `"auto"`, `"mixed"` |
| `mode` | `Settings.currentModeName` | `"Raw"` is a valid override (forces no AI rewrite for this app) |
| `spokenPunctuation` | `Settings.spokenPunctuationEnabled` | `true`/`false` |
| `translate` | `Settings.translateToEnglish` | `true`/`false` |

**Matching rules:** the first rule in the array whose `bundleId` matches OR
whose `app` matches wins — either field matching is enough, you don't need
both. Rules are checked in order, top to bottom, and only the first match is
used. A field left out of a matched rule simply falls back to your base
Settings for that dictation (only non-null override fields apply).

**Worked examples** (using the profiles above):
- Dictating in **Slack** → the "Slack" rule matches on `app`; your text is
  rewritten in Message mode, but language/punctuation/translate stay
  whatever your base Settings say.
- Dictating in **Mail** (bundle ID `com.apple.mail`) → matches on
  `bundleId`; Email mode is applied.
- Dictating in **Terminal** → matches on `app`; spoken punctuation is forced
  off for this app even if you have it enabled globally (handy since you
  probably don't want "koma" turning into a literal comma in shell commands).
- Dictating in any other app (e.g. Notes) → no rule matches; every setting
  falls back to your base Settings/menu selections.

The recording pill's caption always reflects the *effective* (post-profile)
language and mode, so you can see at a glance which override applied before
you even finish speaking.

---

## 8. AI modes

AI modes rewrite your raw dictated text through a **local** Ollama model
before pasting — e.g. turning a casual ramble into a polished email. This
is entirely optional: the default mode, **Raw**, applies no rewriting at
all, and nothing is ever sent to Ollama unless you've picked a non-Raw mode.

Modes live in `~/Library/Application Support/MyWhisper/modes.json`, a plain
JSON array. The three that ship by default:

```json
[
  {"name": "Email", "prompt": "Rewrite the dictated text as a clear, polite email body. Keep the language of the input. Output only the rewritten text.", "model": null},
  {"name": "Message", "prompt": "Rewrite the dictated text as a short, casual chat message. Keep the language of the input. Output only the rewritten text.", "model": null},
  {"name": "Bullet Notes", "prompt": "Rewrite the dictated text as concise bullet notes. Keep the language of the input. Output only the bullets.", "model": null}
]
```

Each entry has:
- **`name`** — shown in the Mode menu/popup.
- **`prompt`** — the system prompt sent to Ollama along with your dictated
  text. You can write your own modes here.
- **`model`** — optional; a specific Ollama model name for just this mode
  (e.g. a bigger/smaller model than your default). When `null` or omitted,
  the mode uses whatever's in the **Ollama model** field in Settings.

### {app} and {selection} placeholders

Your prompt text can include the literal placeholders `{app}` and
`{selection}`, which get filled in at dictation time with:
- `{app}` — the name of the frontmost application when you started
  dictating.
- `{selection}` — whatever text was selected (via the Accessibility API) in
  that app at that moment, truncated to 2000 characters.

Example: a "Reply" mode with the prompt `"Draft a reply appropriate for
{app}. The user had this selected: {selection}. Output only the reply."`
lets you dictate a rough idea while some existing text is selected, and get
back a reply that's aware of both the app you're in and what you'd
highlighted.

### Failure fallback behavior

If the Ollama rewrite fails for any reason (Ollama isn't running, the model
isn't pulled, a network hiccup, an empty/garbled response), MyWhisper never
just drops your dictation: it **pastes the raw, un-rewritten transcript
instead** and shows a notification explaining that the AI rewrite failed.
Your words are never lost to an AI-mode failure.

### Privacy note

Before sending any text to Ollama, MyWhisper first verifies the endpoint
really is Ollama by calling `/api/version` and checking the response shape —
refusing to send your dictation (or any `{selection}` text) if something
else is unexpectedly listening on that port. Everything targets
`127.0.0.1:11434` by default; nothing about AI modes ever leaves your Mac.

---

## 9. Teaching it your words

`~/Library/Application Support/MyWhisper/replacements.json` (open via
**Edit Text Replacements…**) holds two independent things:

```json
{
  "vocabulary": ["MyWhisper", "whisper.cpp", "Jakarta"],
  "replacements": [{"find": "my whisper", "replace": "MyWhisper"}]
}
```

- **`vocabulary`** — a plain list of words/phrases (names, product jargon,
  places) you say often. These are joined together and fed to whisper as a
  priming prompt *before* transcription starts, biasing recognition toward
  spelling them correctly — this is a hint, not a guarantee, but it noticeably
  helps with names whisper would otherwise mangle. Especially useful
  alongside Mixed-language mode.
- **`replacements`** — literal find→replace fixes applied *after*
  transcription, case-insensitively, to every dictation. Good for
  consistent mishears whisper makes no matter what ("my whisper" → 
  "MyWhisper").

### The History → Correct… learning flow

You don't have to hand-edit this JSON to teach MyWhisper a fix — there's a
guided flow from your dictation history:

1. Open **History…** from the menu bar.
2. Find the transcription that came out wrong, select its row, and click
   **Correct…**.
3. An editable text box appears pre-filled with the original transcript.
   Edit it to what it *should* have said, and click **Save**.
4. MyWhisper compares your edit against the original and tries to derive a
   minimal, reusable find→replace rule — trimming the longest common
   prefix/suffix (aligned to whole-word boundaries) so the rule captures
   just the part that changed, not the whole sentence.
5. If a sane rule can be derived, it's saved straight into
   `replacements.json` — updating an existing rule with the same `find` text
   in place, rather than duplicating it, if you'd already corrected that
   same phrase before. You'll see a "Correction saved" notification showing
   the exact `find → replace` pair.
6. From then on, every future dictation containing that phrase is
   auto-corrected.

If the edit is too broad or doesn't reduce to a sane rule (e.g. you rewrote
the whole sentence, or the "find" text would be unreasonably long/generic),
you'll see a "No reusable rule" notification instead, and nothing is saved —
edit `replacements.json` by hand for cases like that.

---

## 10. Transcribing audio files

Besides live dictation, MyWhisper can transcribe an existing audio file you
already have (a voice memo, a recorded meeting snippet, etc.):

1. Menu bar → **Transcribe Audio File…**.
2. Pick any audio file in the file picker (any format your Mac can already
   decode via its built-in audio frameworks — WAV, AIFF, MP3, M4A, CAF, and
   more; anything AVFoundation can read).
3. A **File Transcript** window opens showing "Transcribing `<filename>`…",
   then fills in with the transcript once done, along with a live character
   and word count and a **Copy** button.

File transcription always uses your current language/translate settings,
but — unlike live dictation — it's treated as **verbatim**: no AI-mode
rewrite, no voice-command interception, and no spoken-punctuation
processing, since a file transcript usually isn't meant to be edited spoken
dictation. It's saved into History the same as any live transcription
(unless Save History is off).

MyWhisper won't let you start a file transcription while already dictating
or transcribing something else — you'll get a "Still busy" notification
instead.

### CLI equivalent

```sh
.build/release/MyWhisper --transcribe recording.wav --language en
```

See [section 12](#12-the-cli) for every flag.

---

## 11. History

Open with **History…** from the menu bar. Shows every saved transcription,
newest first, each with its timestamp and text.

- **Double-click a row** — copies that transcript's text to your clipboard
  and shows a brief notification confirming it.
- **Select a row, click Correct…** — the correction-learning flow described
  in [section 9](#the-history--correct-learning-flow).
- **Clear History** — empties the history file entirely (irreversible).
- **Save History** toggle (menu bar or Settings) — turn off to stop writing
  new dictations to history at all; existing history is left alone.
- **Where it lives** — `~/Library/Application
  Support/MyWhisper/history.json`, restricted to owner-only read/write
  (0600 file permissions) since it holds cleartext dictation text.
- **200-entry cap** — history keeps only the most recent 200 entries; older
  ones are dropped automatically as new ones are added, oldest first.

---

## 12. The CLI

MyWhisper can transcribe a file from the command line without opening any
windows — useful for scripting or testing:

```sh
MyWhisper                                    # runs the normal menu-bar app
MyWhisper --help / -h                        # prints usage and exits
MyWhisper --transcribe <audio-file>          # transcribes a file, prints text, exits
    [--language <code|auto>]                 # e.g. en, id, mixed, auto (default: your saved setting)
    [--translate]                            # translate speech to English instead of transcribing
    [--mode <name>]                          # apply an AI mode by name (default: your saved setting)
    [--engine server|inprocess]              # pick the transcription backend (default: your saved setting)
```

Examples:

```sh
# Plain transcription, printed to stdout
.build/release/MyWhisper --transcribe meeting.wav

# Force Indonesian, in-process engine
.build/release/MyWhisper --transcribe catatan.wav --language id --engine inprocess

# Rewrite through the Email AI mode
.build/release/MyWhisper --transcribe voicenote.wav --mode Email
```

The file doesn't have to be a raw 16 kHz mono WAV — anything your Mac's
audio frameworks can decode is accepted (the same fallback used by
"Transcribe Audio File…"). Text is printed to stdout; errors go to stderr
with a non-zero exit code. Voice-command interception is disabled for the
CLI (a transcript that happens to be exactly "new line" is printed
literally, not executed), and per-app context substitution ({app}/
{selection}) isn't available outside the GUI.

---

## 13. Where your data lives

Everything MyWhisper stores lives under
`~/Library/Application Support/MyWhisper/`, which is locked down to
owner-only access (`0700` on the directory itself) since it can hold
cleartext dictation.

| File/folder | Format | Permissions | What it holds |
|---|---|---|---|
| `models/` | folder of `ggml-*.bin` files | 0700 dir, 0600 per model file | Downloaded whisper.cpp speech models |
| `history.json` | JSON array of `{date, text, language}` | 0600 | Your last 200 dictations (see section 11) |
| `replacements.json` | JSON object `{vocabulary: [...], replacements: [{find, replace}]}` | 0600 | Custom vocabulary + text-fix rules (section 9) |
| `modes.json` | JSON array of `{name, prompt, model}` | created on first use, no special lockdown beyond the directory | Your AI modes (section 8) |
| `profiles.json` | JSON array of `{app, bundleId, language, mode, spokenPunctuation, translate}` | created on first use | Per-app overrides (section 7) |
| `whisper-server.log` | plain text | inherits directory perms | stdout/stderr of the `whisper-server` subprocess — check here first for engine problems |

Settings themselves (hotkey, language, toggles, etc.) are stored separately
in macOS's standard `UserDefaults`/`defaults` system under the identifier
`com.ronimoe.mywhisper`, not as a file in this folder.

---

## 14. Troubleshooting

**"No model — run: make model" / model missing.** MyWhisper couldn't find
any speech model — happens only on a bare/dev build with no bundled starter
and nothing yet downloaded to `~/Library/Application
Support/MyWhisper/models/`. Fix: open the Setup Assistant and click
**Download**, or run `make model` from the source checkout.

**"port `<N>` is already in use by another process…"** MyWhisper refuses to
start its local transcription server if something else already has that
port (default `8178`) bound — this is a deliberate privacy safeguard so your
audio never accidentally gets POSTed to an unknown listener. Fix: quit
whatever else is using that port, or change the port via
`defaults write com.ronimoe.mywhisper serverPort -int <newport>` and restart
MyWhisper.

**Mic seems silent / level bars don't move.** Check **System Settings →
Privacy & Security → Microphone** — make sure MyWhisper is listed and
enabled. If you just granted it, you may need to quit and relaunch
MyWhisper once. Also check the correct input device is selected in **System
Settings → Sound → Input**.

**Paste isn't happening (text only lands in clipboard).** This means
Accessibility permission isn't currently granted. A common cause after
rebuilding the app from source: this build is signed ad-hoc (or with a local
self-signed "MyWhisper Dev" certificate), and macOS's permission system
(TCC) treats a differently-signed binary as a new app — so Accessibility
needs to be **re-granted** after each rebuild. Fix: **System Settings →
Privacy & Security → Accessibility**, remove the old MyWhisper entry if
present, then re-add/re-enable it (or use the Setup Assistant's
**Open System Settings…** button, which also re-arms the system prompt).

**Ollama / AI-mode states.** In the Setup Assistant's "AI modes" section:
- *"Ollama not installed (or not running)"* — install/launch Ollama, or if
  it's already running, check it's actually listening on
  `127.0.0.1:11434` (the default MyWhisper expects).
- *"Ollama is running — needs an AI model"* — click **Download AI Model**,
  or run `ollama pull llama3.2` (or your configured model name) yourself.
- If an AI-mode rewrite fails mid-dictation, MyWhisper always falls back to
  pasting the raw transcript and shows a notification with the error — your
  words are never lost, only the rewrite step is skipped that one time.

**Reset the Setup Assistant** so it shows again on next launch:
```sh
defaults write com.ronimoe.mywhisper hasCompletedOnboarding -bool false
```
(Or just reopen it anytime via the menu bar — you don't actually need to
reset anything to see it again.)

**Server log location.** `~/Library/Application
Support/MyWhisper/whisper-server.log` — also reachable via **Open Server
Log** in the menu bar or Settings window. Check here first for anything
related to model loading or the transcription engine failing to start; the
app also surfaces the last few lines of this log automatically in its own
error messages when the server process crashes.
