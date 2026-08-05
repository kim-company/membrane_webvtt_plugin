defmodule Membrane.WebVTT.FilterTest do
  use ExUnit.Case

  import Membrane.ChildrenSpec

  alias Membrane.{Buffer, Testing}
  alias Membrane.WebVTT.Filter

  test "verbatim layout bypasses automatic line formatting" do
    text = "  First authored line  \nSecond line far too long  "

    buffer = %Buffer{
      pts: 0,
      payload: text,
      metadata: %{to: Membrane.Time.seconds(2), text_layout: :verbatim}
    }

    assert [%Buffer{payload: ^text}] = run_filter([buffer], max_length: 5, max_lines: 1)
  end

  test "canonical text still uses automatic line formatting" do
    buffer = buffer("This sentence is automatically formatted", 0, 2)

    output = run_filter([buffer], max_length: 8, max_lines: 1)

    refute Enum.map(output, & &1.payload) == [buffer.payload]
    assert Enum.all?(output, &(String.length(&1.payload) <= 8))
  end

  test "switching layouts flushes canonical text without changing authored text" do
    authored = "Authored first line\nAuthored second line"

    buffers = [
      buffer("canonical before", 0, 2),
      buffer(authored, 2, 4, %{text_layout: :verbatim}),
      buffer("canonical after", 4, 6)
    ]

    assert Enum.map(run_filter(buffers, max_length: 40, max_lines: 1), & &1.payload) == [
             "canonical before",
             authored,
             "canonical after"
           ]
  end

  defp buffer(payload, from, to, metadata \\ %{}) do
    %Buffer{
      pts: Membrane.Time.seconds(from),
      payload: payload,
      metadata: Map.put(metadata, :to, Membrane.Time.seconds(to))
    }
  end

  defp run_filter(buffers, options) do
    spec =
      child(:source, %Testing.Source{output: buffers, stream_format: %Membrane.Text{}})
      |> child(:filter, struct!(Filter, options))
      |> child(:sink, Testing.Sink)

    pipeline = Testing.Pipeline.start_link_supervised!(spec: spec)

    buffers = collect_buffers(pipeline, [])
    Testing.Pipeline.terminate(pipeline)
    buffers
  end

  defp collect_buffers(pipeline, buffers) do
    receive do
      {Testing.Pipeline, ^pipeline, {:handle_child_notification, {{:buffer, buffer}, :sink}}} ->
        collect_buffers(pipeline, [buffer | buffers])

      {Testing.Pipeline, ^pipeline, {:handle_element_end_of_stream, {:sink, :input}}} ->
        Enum.reverse(buffers)
    end
  end
end
