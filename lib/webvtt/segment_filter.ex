defmodule Membrane.WebVTT.SegmentFilter do
  use Membrane.Filter

  alias Membrane.{Buffer, Time}
  alias Subtitle.WebVTT

  def_input_pad :input,
    availability: :always,
    accepted_format: Membrane.Text

  def_output_pad :output,
    availability: :always,
    accepted_format: Membrane.Text

  def_options segment_duration: [spec: Time.t(), default: Time.seconds(6)],
              headers: [
                spec: [%WebVTT.HeaderLine{}],
                default: [%Subtitle.WebVTT.HeaderLine{key: :description, original: "WEBVTT"}]
              ]

  defmodule State do
    defstruct duration: nil,
              segment_start: 0,
              segment_end: nil,
              buffers: [],
              headers: []
  end

  @impl true
  def handle_init(_ctc, options) do
    {[],
     %State{
       duration: options.segment_duration,
       segment_end: options.segment_duration,
       headers: options.headers
     }}
  end

  @impl true
  def handle_buffer(:input, %Buffer{} = buffer, _ctx, %State{} = state) do
    # Convert timestamps
    add_buffer(state, buffer)
  end

  @impl true
  def handle_end_of_stream(_, _ctx, %State{} = state) do
    if state.buffers != [] do
      last = hd(state.buffers)

      segment =
        build_output_buffer(state.buffers, state.headers, state.segment_start, last.metadata.to)

      {[segment | [end_of_stream: :output]], state}
    else
      {[end_of_stream: :output], state}
    end
  end

  defp add_buffer(state, buffer) do
    case buffer.metadata.to - state.segment_end do
      # buffer ends in the current segment
      x when x < 0 ->
        # Add buffer to accumulator for this segment
        new_state = %State{state | buffers: [buffer | state.buffers]}
        {[], new_state}

      # Buffer bleeds into next fragment 
      x when x >= 0 ->
        # Flush buffer and advance state to next fragment
        segment =
          build_output_buffer(
            [buffer | state.buffers],
            state.headers,
            state.segment_start,
            state.segment_end
          )

        state = %State{
          state
          | buffers: [],
            segment_start: state.segment_end,
            segment_end: state.segment_end + state.duration
        }

        {segments, state} =
          if x == 0 do
            # buffer ends exactly within this segment
            {[], state}
          else
            # Recursively call function until segment is wihtin the segment boundaries
            add_buffer(state, buffer)
          end

        {[segment | segments], state}
    end
  end

  defp build_output_buffer(buffers, headers, segment_start, segment_end) do
    cues =
      buffers
      |> Enum.reverse()
      |> Enum.reject(&(&1.payload == ""))
      |> Enum.map(&buffer_to_cue/1)

    webvtt =
      %Subtitle.WebVTT{cues: cues, header: headers}
      |> WebVTT.marshal!()
      |> to_string()

    {:buffer,
     {:output,
      %Buffer{
        pts: segment_start,
        payload: webvtt,
        metadata: %{to: segment_end, duration: segment_end - segment_start}
      }}}
  end

  defp buffer_to_cue(buffer) do
    %Subtitle.Cue{
      text: buffer.payload,
      from: Time.as_milliseconds(buffer.pts, :round),
      to: Time.as_milliseconds(buffer.metadata.to, :round)
    }
  end
end
