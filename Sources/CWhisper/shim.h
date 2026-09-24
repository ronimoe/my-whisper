// whisper.h does `#include "ggml.h"`, and ggml.h lives in the Homebrew umbrella
// include dir (symlinked from the ggml formula), not the whisper Cellar dir
// that whisper.pc exposes. Package.swift adds `-I$HOMEBREW_PREFIX/include`.
#include <whisper.h>

// ggml_backend_load_all() lives here. whisper's own CLI tools call it at
// startup so the dynamically-loaded ggml backends (Metal, CPU) get registered
// before whisper_init; without it, whisper_init aborts on GGML_ASSERT(device).
#include <ggml-backend.h>
