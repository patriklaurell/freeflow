# FreeFlow Local

FreeFlow Local is an Apple Silicon macOS application with in-process Parakeet v3 transcription and optional Qwen 3.5 4B cleanup. It needs no inference server. Model provisioning is the only new network path; ordinary local dictation does not use cloud transcription, cloud cleanup, screenshots, API credentials, or the upstream updater. The original Make build retains the upstream providers and macOS 13 target. The local build targets macOS 14+.

## Build

Use a full Xcode installation with Swift 6.2 or later and its **Metal Toolchain** component. This handoff was checked using Xcode 27 / Swift 6.4. Make explicitly selects Swift Build for the local product so Metal shaders are compiled and bundled; a legacy native SwiftPM build alone is not a distributable MLX application.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
make check
make ARCH=arm64 CODESIGN_IDENTITY=-
make local CODESIGN_IDENTITY=-
```

If `xcrun metal --version` reports a missing component, install it through Xcode Settings → Components, or run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -downloadComponent MetalToolchain
```

The first build fetches pinned Swift dependencies. `Package.resolved` records transitive versions. FluidAudio's optional traits are disabled, though SwiftPM may still download its declared binary artifact while resolving the package.

The output is `build/FreeFlow Local.app`. Make packages the MLX Metal library, tokenizer resources, privacy manifests, and dependency license notices before signing. Packaging fails if required bundles are missing. `CODESIGN_IDENTITY=-` is an ad-hoc signature for local testing. For distribution, pass your Developer ID Application identity, verify the signature, and complete your normal notarization process; no release or notarization is performed by this handoff.

```sh
codesign --verify --deep --strict 'build/FreeFlow Local.app'
otool -L 'build/FreeFlow Local.app/Contents/MacOS/FreeFlow Local'
```

In an agent filesystem sandbox, builds used writable compiler caches and disabled Swift's nested build subprocess sandbox (the outer agent sandbox remains in force):

```sh
export CLANG_MODULE_CACHE_PATH=/tmp/freeflow-xcode-clang-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/tmp/freeflow-xcode-swift-cache
make check SWIFT_FLAGS=-disable-sandbox
make local CODESIGN_IDENTITY=- SWIFTPM_FLAGS='--disable-sandbox -Xswiftc -disable-sandbox'
```

## Models and offline operation

Settings → Local Transcription provides **Download / repair** and **Verify installed model** for each pinned model. Downloads use a staging directory, validate every file's size and SHA-256, and replace the installed directory only after successful verification. Transient URLSession errors are retried, using resume data when available. Cancellation and failed verification preserve the previous installation. First inference verifies the required model files again; subsequent requests reuse the loaded model. Restart after manually replacing a loaded model.

| Model | Repository | Revision | Required size |
| --- | --- | --- | --- |
| Speech | `FluidInference/parakeet-tdt-0.6b-v3-coreml` | `7dd20fe6b1797d35f5e3307e8b1732d9a178edfe` | 483 MB |
| Optional cleanup | `mlx-community/Qwen3.5-4B-4bit` | `0e7ffd5c629ef7719d4cbc04069232580bfa9d9c` | about 3.05 GB |

Files live under `~/Library/Application Support/FreeFlow Local/Models/`. The exact versioned filenames and checksums are in `Sources/LocalModelCatalog.swift`. You may also copy a verified installation from another machine. Missing or damaged weights fail locally; inference never downloads a model implicitly.

Parakeet layout:

```text
parakeet-tdt-0.6b-v3-coreml/
  Preprocessor.mlmodelc/
  Encoder.mlmodelc/
  Decoder.mlmodelc/
  JointDecisionv3.mlmodelc/
  parakeet_vocab.json
```

Qwen layout:

```text
Qwen3.5-4B-4bit/
  config.json
  model.safetensors
  model.safetensors.index.json
  tokenizer.json
  tokenizer_config.json
  chat_template.jinja
```

Cleanup defaults off. Enable **Clean up dictation on this Mac** after verifying Qwen. Exact-wording shortcuts and macros bypass it. Cleanup receives only the transcript and vocabulary, with fresh conversation state per request. JSON encoding separates transcript data from system instructions. Output checks reject malformed responses, large rewrites, and detected number or negation changes. These checks cannot prove semantic equivalence: assess meaning, language, and style on a representative corpus. Any cleanup error returns raw transcription, with a fallback status in history.

## Vocabulary learning

**Suggest vocabulary from edits after dictation** defaults off. With this option enabled, supported focused Accessibility text fields are observed for at most 30 seconds after an insertion is confirmed. Secure and unsupported controls are excluded; losing focus, restarting recording, disabling learning, or changing text outside the inserted span ends observation. Automatic Enter submissions are not watched.

A suggestion requires one plausible spelling replacement in an otherwise unchanged sentence. Suggestions stay in memory. **Review** opens an editable pair; **Approve and save** persists it. Approved entries can be edited or removed, and manual pairs can be added. Only approved word/phrase pairs are stored in `~/Library/Application Support/FreeFlow Local/vocabulary.json`, with owner-only file permissions. A corrupt vocabulary file is preserved rather than overwritten. Field snapshots are never written by the learning component. Existing upstream dictation history settings still apply to recordings and transcripts.

Approved pairs and the existing custom vocabulary guide optional cleanup. They do not retrain or modify Parakeet weights. Conservative extraction will miss some corrections, especially in editors with incomplete Accessibility support.

## Pipeline map

| Stage | Integration |
| --- | --- |
| Recording | Existing hotkeys, shortcut sessions, and `AudioRecorder`. |
| Transcription | `AppState.makeTranscriptionService()` → `LocalFileTranscriptionService` → `ParakeetTranscriber`; shared loaded weights, fresh decoder state. |
| Cleanup | `AppState.processTranscript()` → `TranscriptCleanupService` → `QwenCleanup`; independently replaceable from ASR. |
| Insertion | Existing `insertTranscriptWhenShortcutReleased`, clipboard restoration, and original-field insertion paths. |
| Learning | Local post-insertion hooks → `LocalVocabularyController` → in-memory suggestions → explicit approval in `LearnedVocabularyStore`. |
| Provisioning | Settings → `LocalModelInstaller`; immutable revision URLs and checked-in hashes. |

## Verification on the target Mac

Build the runners while connected:

```sh
swift build --build-system swiftbuild -c release --arch arm64 --product ParakeetSmoke
swift build --build-system swiftbuild -c release --arch arm64 --product CleanupSmoke
swift build --build-system swiftbuild -c release --arch arm64 --show-bin-path
```

Use the returned directory; Swift 6.4's Swift Build output is typically `.build/out/Products/Release`, rather than the older `.build/arm64-apple-macosx/release` path. Do not invoke SwiftPM during the offline test; invoke already-built binaries directly.

Generate synthetic fixtures in a normal Terminal session:

```sh
say -v 'Samantha (English (US))' -o english.aiff 'The blue bicycle is outside.'
say -v 'Alva (Swedish (Sweden))' -o swedish.aiff 'Den blå cykeln står utanför.'
afinfo english.aiff
afinfo swedish.aiff
```

Verify nonzero audio duration. Disconnect networking, then invoke:

```sh
BIN_DIR=/path/reported/by/show-bin-path
MODEL_ROOT="$HOME/Library/Application Support/FreeFlow Local/Models"
"$BIN_DIR/ParakeetSmoke" "$MODEL_ROOT/parakeet-tdt-0.6b-v3-coreml" \
  english.aiff 'The blue bicycle is outside.' swedish.aiff 'Den blå cykeln står utanför.'
"$BIN_DIR/CleanupSmoke" "$MODEL_ROOT/Qwen3.5-4B-4bit"
```

ParakeetSmoke reports cold English, warm Swedish, warm English, normalized word errors, elapsed time, and process peak resident bytes. It evaluates all three passes before reporting mismatches. `--load-only MODEL_DIRECTORY` checks loading without speech evaluation. CleanupSmoke checks English/Swedish punctuation and number/negation preservation. All fixtures are synthetic; do not add private recordings to the repository.

Then use the signed app offline in TextEdit. Verify onboarding, microphone and Accessibility permission handling, hold/toggle shortcuts, Paste Again, original-field insertion, and clipboard restoration. Repeat with cleanup on/off and with unavailable cleanup weights. Test vocabulary review/edit/removal across an app restart; ensure toggling learning off stops observation and unapproved suggestions do not survive restart.

Measure recording-stop to confirmed insertion (separately from the smoke runner's ASR time), cold/warm runs, peak memory, and WER on a labeled English/Swedish corpus. Include names, technical terms, accented and mixed-language speech. Check cleanup meaning and style manually. Record hardware, macOS, model revisions and clip durations. Two synthetic sentences establish a smoke test only, not general language accuracy.

## Handoff validation status — 2026-11-19

- Patched clean upstream commit `37786464bb2422c58313d7456fe7191d115d0d18` on branch `local-parakeet`.
- `make check` passes with the sandbox build flags above. Includes regression tests for word errors, cleanup response checks, vocabulary approval/persistence/removal, and failed/cancelled/corrupt model installation.
- Original arm64 application built and ad-hoc signed. Pre-MLX local application built and ad-hoc signed.
- Parakeet's 21 model files were provisioned and verified. Its first observed load completed in 7.613 seconds. A repeat process load took 6.462 seconds with 2,546,073,600 peak resident bytes. These are model-load probes, not speech or insertion latency.
- Qwen weights and tokenizer files were downloaded from the pinned revision and verified against their recorded SHA-256 hashes. Weight loading and GPU generation remain unverified.
- The full app source, including MLX, compiles and links with the native build engine. Qwen tokenizer round trips pass for English and Swedish, and its local chat template renders successfully. GPU bundle and generation validation remain pending the missing Xcode Metal Toolchain component.
- macOS speech synthesis is blocked in the agent sandbox; English/Swedish audio inference, WER, physically disconnected networking, microphone-to-insertion tests, and Accessibility learning need a normal desktop session.
- Developer ID distribution signing and notarization have not been performed. Nothing was released or merged.
