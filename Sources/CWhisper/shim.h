// Use the Homebrew umbrella include dir (/opt/homebrew/include) rather than the
// whisper Cellar dir that whisper.pc exposes: whisper.h does `#include "ggml.h"`,
// and ggml.h only lives here (symlinked from the ggml formula's Cellar).
#include "/opt/homebrew/include/whisper.h"

// ggml_backend_load_all() lives here. whisper's own CLI tools call it at
// startup so the dynamically-loaded ggml backends (Metal, CPU) get registered
// before whisper_init; without it, whisper_init aborts on GGML_ASSERT(device).
#include "/opt/homebrew/include/ggml-backend.h"
