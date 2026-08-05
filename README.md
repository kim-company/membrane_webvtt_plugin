# Membrane.WebVTT.Plugin
Filter for formatting and segmenting WebVTT cues.

```elixir
def deps do
  [
    {:membrane_webvtt_plugin, "~> 3.0"}
  ]
end
```

Canonical text is formatted according to the filter options. To preserve an authored final line
layout, mark a buffer with `metadata: %{text_layout: :verbatim}`. The payload is then emitted
unchanged; callers remain responsible for supplying valid WebVTT cue text.
