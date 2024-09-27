defmodule Membrane.WebVTT.CueBuilderFilter do
  use Membrane.Filter

  alias Membrane.{Buffer, Time}
  alias Subtitle.Cue.Builder

  def_input_pad :input,
    availability: :always,
    accepted_format: Membrane.Text

  def_output_pad :output,
    availability: :always,
    accepted_format: Membrane.Text

  def_options max_length: [spec: integer(), default: nil],
              min_duration: [spec: Time.t(), default: nil],
              max_lines: [spec: integer(), default: nil]

  @impl true
  def handle_init(_ctc, options) do
    opts =
      Enum.filter(
        [
          max_length: options.max_length,
          min_duration:
            options.min_duration && Time.as_microseconds(options.min_duration, :round),
          max_lines: options.max_lines
        ],
        &elem(&1, 1)
      )

    {[], {nil, Builder.new(opts)}}
  end

  @impl true
  def handle_buffer(
        :input,
        %Buffer{pts: pts, payload: sentence, metadata: %{to: to}} = buffer,
        _ctx,
        {_, builder}
      ) do
    cue = %Subtitle.Cue{
      text: sentence,
      from: Membrane.Time.as_milliseconds(pts, :round),
      to: Membrane.Time.as_milliseconds(to, :round)
    }

    {builder, cues} =
      if cue.text == "" do
        {builder, flushed_cue} = Builder.flush(builder)
        {builder, List.wrap(flushed_cue) ++ [cue]}
      else
        Builder.put_and_get(builder, cue)
      end

    {build_output_buffers(buffer, cues), {buffer, builder}}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, {last_buffer, builder}) do
    {builder, cue} = Builder.flush(builder)
    {build_output_buffers(last_buffer, cue) ++ [end_of_stream: :output], {last_buffer, builder}}
  end

  defp build_output_buffers(buffer, cues) do
    cues
    |> List.wrap()
    |> Enum.map(fn cue ->
      pts = Time.milliseconds(cue.from)
      metadata = %{buffer.metadata | to: Time.milliseconds(cue.to)}
      {:buffer, {:output, %Buffer{buffer | payload: cue.text, pts: pts, metadata: metadata}}}
    end)
  end
end
