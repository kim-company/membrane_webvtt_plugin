defmodule Membrane.WebVTTTest do
  use ExUnit.Case, async: true
  use Membrane.Pipeline

  import Membrane.Testing.Assertions

  alias Membrane.{Buffer, Testing, Time}
  alias Membrane.WebVTT.{CueBuilderFilter, SegmentFilter}

  test "converts sentences to webvtt" do
    t1 = "This is a test."
    t2 = "This is a second test."
    t3 = "This is the third test"
    t4 = "This is the forth test"
    t5 = "This is the fifth test"

    sentences = [
      %Buffer{
        pts: Time.seconds(0),
        metadata: %{to: Time.seconds(5)},
        payload: t1
      },
      %Buffer{
        pts: Time.seconds(5),
        metadata: %{to: Time.seconds(25)},
        payload: t2
      },
      %Buffer{
        pts: Time.seconds(25),
        metadata: %{to: Time.seconds(45)},
        payload: t3
      },
      %Buffer{
        pts: Time.seconds(45),
        metadata: %{to: Time.seconds(60)},
        payload: t4
      },
      %Buffer{
        pts: Time.seconds(60),
        metadata: %{to: Time.seconds(80)},
        payload: ""
      },
      %Buffer{
        pts: Time.seconds(80),
        metadata: %{to: Time.seconds(100)},
        payload: t5
      }
    ]

    links = [
      child(:source, %Testing.Source{
        output: sentences,
        stream_format: %Membrane.Text{locale: "en"}
      })
      |> child(:cues, CueBuilderFilter)
      # |> child(:cues_dbg, %Membrane.Debug.Filter{handle_buffer: &dbg/1})
      |> child(:segments, SegmentFilter)
      # |> child(:segment_dbg, %Membrane.Debug.Filter{handle_buffer: &dbg/1})
      |> child(:sink, %Testing.Sink{})
    ]

    pid = Testing.Pipeline.start_link_supervised!(spec: links)

    # from, to, must contain, must not contain
    matches = [
      {0, 6, [t1, t2], []},
      {6, 12, [t2], [t1, t3]},
      {12, 18, [t2], [t3]},
      {18, 24, [t2], [t3]},
      {24, 30, [t2, t3], [t4]},
      {30, 36, [t3], [t2, t4]},
      {36, 42, [t3], [t4]},
      {42, 48, [t3, t4], [t2, t5]},
      {48, 54, [t4], [t3, t5]},
      {54, 60, [t4], [t5]},
      {60, 66, [], [t5]},
      {66, 72, [], [t4, t5]},
      {72, 78, [], [t4, t5]},
      {78, 84, [t5], [t4]},
      {84, 90, [t5], [t4]},
      {90, 96, [t5], [t4]},
      {96, 100, [t5], [t4]}
    ]

    for {from, to, asserts, refutes} <- matches do
      from = Time.seconds(from)
      to = Time.seconds(to)

      assert_sink_buffer(pid, :sink, %Membrane.Buffer{
        payload: payload,
        pts: ^from,
        metadata: %{to: ^to}
      })

      for text <- asserts do
        assert(payload =~ text, "#{inspect(text)} not in #{inspect(payload)} at PTS #{from}")
      end

      for text <- refutes do
        refute(payload =~ text, "#{inspect(text)} in #{inspect(payload)} at PTS #{from}")
      end
    end
  end
end
