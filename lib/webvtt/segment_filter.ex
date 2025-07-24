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
              ],
              omit_repetition: [
                spec: boolean(),
                default: false,
                description:
                  "When true, cues that span across segment boundaries are not repeated in both segments"
              ],
              resume: [
                spec: boolean(),
                default: false,
                description:
                  "When true, the first segment emitted is the one that cat fit the first buffer received. If false, emits segments from 0"
              ]

  @impl true
  def handle_init(_ctc, opts) do
    segment =
      unless opts.resume do
        new_segment(0, opts.segment_duration)
      end

    {[],
     %{
       omit_repetition: opts.omit_repetition,
       segment_duration: opts.segment_duration,
       headers: opts.headers,
       segment: segment
     }}
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, state = %{segment: nil}) do
    # If the segment is nil, it means this is the first buffer
    # and the option resume was set.
    index = div(buffer.pts, state.segment_duration)
    from = index * state.segment_duration
    to = from + state.segment_duration
    segment = new_segment(from, to)
    state = put_in(state, [:segment], segment)
    handle_buffer(:input, buffer, ctx, state)
  end

  def handle_buffer(:input, buffer, _ctx, state) do
    {buffers, state} = put_and_get(state, buffer, [])
    {[buffer: {:output, buffers}], state}
  end

  @impl true
  def handle_end_of_stream(_, _ctx, state) do
    {buffer, state} =
      get_and_update_in(state, [:segment], fn segment ->
        {segment_to_buffer(segment, state), nil}
      end)

    {[buffer: {:output, buffer}, end_of_stream: :output], state}
  end

  defp buffer_to_cue(buffer) do
    %Subtitle.Cue{
      text: buffer.payload,
      from: Time.as_milliseconds(buffer.pts, :round),
      to: Time.as_milliseconds(buffer.metadata.to, :round)
    }
  end

  defp new_segment(from, to) do
    %{from: from, to: to, queue: :queue.new()}
  end

  defp next_segment(state) do
    previous = state.segment
    next = new_segment(previous.to, previous.to + state.segment_duration)
    put_in(state, [:segment], next)
  end

  defp segment_to_buffer(%{from: from, to: to, queue: queue}, state) do
    cues =
      queue
      |> :queue.to_list()
      |> Enum.reject(&(&1.payload == ""))
      |> Enum.map(&buffer_to_cue/1)

    webvtt =
      %Subtitle.WebVTT{cues: cues, header: state.headers}
      |> WebVTT.marshal!()
      |> to_string()

    %Buffer{
      pts: from,
      payload: webvtt,
      metadata: %{to: to, duration: to - from}
    }
  end

  defp put_and_get(state, nil, acc) do
    buffers =
      acc
      |> Enum.reverse()
      |> Enum.map(&segment_to_buffer(&1, state))

    {buffers, state}
  end

  defp put_and_get(state = %{omit_repetition: true}, buffer, acc) do
    segment = state.segment
    from = buffer.pts
    to = buffer.metadata.to

    cond do
      # The buffer starts after. Forward.
      from >= segment.to ->
        state
        |> next_segment()
        |> put_and_get(buffer, [segment | acc])

      # The buffer starts here and ends in the next segment, meaning we have
      # to store the buffer and proceed to the next segment.
      from >= segment.from and to > segment.to ->
        segment = update_in(segment, [:queue], fn q -> :queue.in(buffer, q) end)

        state
        |> next_segment()
        |> put_and_get(nil, [segment | acc])

      # Buffer starts and ends here, we shall not proceed to the next segment.
      from >= segment.from and to <= segment.to ->
        state
        |> update_in([:segment, :queue], fn q -> :queue.in(buffer, q) end)
        |> put_and_get(nil, acc)

      true ->
        # The buffer started before this segment and there is nothing we can
        # do about it. Throw it away.
        state
        |> put_and_get(nil, acc)
    end
  end

  defp put_and_get(state, buffer, acc) do
    segment = state.segment
    from = buffer.pts
    to = buffer.metadata.to

    cond do
      # The buffer starts after. Forward.
      from >= segment.to ->
        state
        |> next_segment()
        |> put_and_get(buffer, [segment | acc])

      # This buffer started in a previous segment and ends here,
      # we're done with it.
      to <= segment.to ->
        state
        |> update_in([:segment, :queue], fn q -> :queue.in(buffer, q) end)
        |> put_and_get(nil, acc)

      # The buffer started before and does not end here. Store and forward.
      true ->
        segment = update_in(segment, [:queue], fn q -> :queue.in(buffer, q) end)

        state
        |> next_segment()
        |> put_and_get(buffer, [segment | acc])
    end
  end
end
