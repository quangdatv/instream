defmodule Instream.WriterTest do
  use ExUnit.Case, async: true

  alias Instream.Data.Read
  alias Instream.Data.Write
  alias Instream.TestHelpers.Connection
  alias Instream.TestHelpers.LineConnection


  defmodule LineEncodingSeries do
    use Instream.Series

    series do
      database    :test_database
      measurement :writer_line_encoding

      field :binary
      field :boolean
      field :float
      field :integer
    end
  end

  defmodule ProtocolsSeries do
    use Instream.Series

    series do
      database    :test_database
      measurement :writer_protocols

      tag :bar
      tag :foo

      field :value
    end
  end


  test "writer protocols" do
    data = %ProtocolsSeries{}
    data = %{ data | tags:   %{ data.tags | foo: "foo", bar: "bar" }}

    # JSON (default) protocol
    data = %{ data | fields: %{ data.fields | value: "JSON" }}

    query  = data |> Write.query()
    result = query |> Connection.execute()

    assert :ok == result

    # Line protocol
    data = %{ data | fields: %{ data.fields | value: "Line" }}

    query  = data |> Write.query()
    result = query |> LineConnection.execute()

    assert :ok == result

    # wait to ensure data was written
    :timer.sleep(250)

    # check data
    result =
         "SELECT * FROM #{ ProtocolsSeries.__meta__(:measurement) } GROUP BY *"
      |> Read.query()
      |> Connection.execute(database: ProtocolsSeries.__meta__(:database))

    assert %{ results: [%{ series: [%{
      values: [[ _, "JSON" ], [ _, "Line" ]]
    }]}]} = result
  end

  test "line protocol data encoding" do
    data = %LineEncodingSeries{}
    data = %{ data | fields: %{ data.fields | binary:  "binary",
                                              boolean: false,
                                              float:   1.1,
                                              integer: 100 }}

    query  = data |> Write.query()
    result = query |> LineConnection.execute()

    assert :ok == result

    # wait to ensure data was written
    :timer.sleep(250)

    # check data
    result =
         "SELECT * FROM #{ LineEncodingSeries.__meta__(:measurement) } GROUP BY *"
      |> Read.query()
      |> Connection.execute(database: LineEncodingSeries.__meta__(:database))

    assert %{ results: [%{ series: [%{
      values: [[ _, "binary", false, 1.1, 100 ]]
    }]}]} = result
  end
end