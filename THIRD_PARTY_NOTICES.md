# Third-party notices

MyWhisper's own code is MIT-licensed (see [LICENSE](LICENSE)). The DMG
release also redistributes the components below, and the source build links
against them. Nothing listed here is committed to this repository: the
engine is built from source by `make deps` and models are downloaded by
`make model`, `scripts/make-dist.sh`, or the app's Setup Assistant.

| Component | Used as | Where it comes from | License |
|---|---|---|---|
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (incl. ggml) | `whisper-server` bundled in the DMG; `libwhisper`/`libggml` linked from Homebrew | built by `make deps`, or `brew install whisper-cpp` | MIT |
| [OpenAI Whisper](https://github.com/openai/whisper) model weights, ggml conversion | starter model `ggml-small-q5_1.bin` bundled in the DMG; larger models downloaded on request | [huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) | MIT |
| [Ollama](https://ollama.com) | optional, installed separately by the user for AI modes; not bundled | ollama.com | MIT; each pulled model has its own license |

## whisper.cpp and ggml

```
MIT License

Copyright (c) 2023-2026 The ggml authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## OpenAI Whisper (model weights)

```
MIT License

Copyright (c) 2022 OpenAI


Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
