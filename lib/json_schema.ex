defmodule JsonSchemaAccessor do
  @behaviour DataSchema.DataAccessBehaviour

  @impl DataSchema.DataAccessBehaviour
  def field(data, path) do
    data |> IO.inspect(limit: :infinity, label: "FIELD DATA")
    path |> IO.inspect(limit: :infinity, label: "FIELD PATH")
  end

  @impl DataSchema.DataAccessBehaviour
  def list_of(data, path) do
  end

  @impl DataSchema.DataAccessBehaviour
  def has_one(data, path) do
  end

  @impl DataSchema.DataAccessBehaviour
  def has_many(data, path) do
  end

  defp get_path(data, path) do
    Enum.reduce_while(path, data, fn node, data ->
      case Map.get(data, node) do
        nil -> {:halt, nil}
        value -> {:cont, value}
      end
    end)
  end
end

defmodule SchemaOne do
  import DataSchema, only: [data_schema: 1]
  @data_accessor JsonSchemaAccessor
  data_schema(field: {:has_one_field, ["first_key"], &__MODULE__.string_type/1})

  def string_type(val) do
    {:ok, val}
  end
end

defmodule SchemaMany do
  import DataSchema, only: [data_schema: 1]
  @data_accessor JsonSchemaAccessor
  data_schema(field: {:has_many_field, ["first_key"], &__MODULE__.string_type/1})

  def string_type(val) do
    {:ok, val}
  end
end

defmodule JsonSchema do
  @moduledoc """
  An experimental module to help test ideas about json schemas and json parsing.

  what's a good path? With JSON you may want to access a list of something, the nth element
  of a list or an object key. You could just have a bare value but in that case you would not
  need this schema approach anyway.

  So if the list is the top level item, how do we say "the list". I think you need a top
  level :all. Do we want to allow this sort of thing?

    [:all, :key_a, :all, :key_b]

  I think the intention of the paths is yes allow it, though it may not be the most
  efficient because it doesn't like group everything together so to speak. Imagine I had
  two paths:

    [:all, :key_a, :all, :key_b]
    [:all, :key_a, :all, :key_c]

  Here we could get key_c at the same time as we are getting key_b if we knew that they
  both had the same ancestors. So when we come to feeding it into a handler we need to like
  tree-ify it somehow and deduplicate the paths. But when specifying the schema we don't
  want to have to enforce that constraint. (We can actually do this at compile time too if
  you don't want to pay the runtime cost. Or do it at runtime but have it saved in ETS
  if compile times get slow).

  ANYWAY. What if you want all of an object? There isn't really any such thing because this
  is specifically about stating up front which fields you wish to extract. (There is a
  separate and interesting space around exploring schemas we can get into later - like
  generating schemas from an example etc).

  [:all]

  example_json =
      {
        "name": "TED DANSON QUEEN",
        "integer": "9999",
        "float": 1.5,
        "decimal": "8.2",
        "string": "take me out to the balls game",
        "list": [1,2,345],
        "aggregate": {
          "date": "10th Feb",
          "time": "4pm"
        }
        "has_many_things": [
          { "first_key": "eat more water" },
          { "first_key": "drink more food" }
        ]
      }

  """
  import DataSchema, only: [data_schema: 1]
  @data_accessor JsonSchemaAccessor
  @aggregate_fields [
    field: {:date, ["aggregate", "date"], &__MODULE__.string_type/1},
    field: {:time, ["aggregate", "time"], &__MODULE__.string_type/1}
  ]
  data_schema(
    field: {:name, ["name"], &__MODULE__.string_type/1},
    field: {:integer, ["integer"], &__MODULE__.integer_type/1},
    field: {:float, ["float"], &__MODULE__.float_type/1},
    field: {:decimal, ["decimal"], &__MODULE__.decimal_type/1},
    field: {:string, ["string"], &__MODULE__.string_type/1},
    list_of: {:list_of_stuff, ["list", :all], &__MODULE__.string_type/1},
    has_many: {:has_many_things, ["has_many"], SchemaOne},
    has_one: {:has_one_thing, ["has_many", {:at, 0}], SchemaMany},
    aggregate: {:aggregate_result, @aggregate_fields, &__MODULE__.aggregate_type/1}
  )

  def test() do
    j = """
      {
        "name": "TED DANSON QUEEN",
        "integer": "9999",
        "float": 1.5,
        "decimal": "8.2",
        "string": "take me out to the balls game",
        "list": [1,2,345],
        "aggregate": {
          "date": "10th Feb",
          "time": "4pm"
        },
        "has_many_things": [
          { "first_key": "eat more water" },
          { "first_key": "drink more food" }
        ]
      }
    """

    j
    |> JxonSlimOriginal.parse(j, OriginalSlimHandler, 0, [])
    |> case do
      # Would be good if the error pointed at the first previous non whitespace char probs?
      # We could actually just backtrack in that case as we are in an error case to perf is out the
      # window in a way.
      {:error, message, byte_index} ->
        :binary.part(j, byte_index - 3, 5)

      dom ->
        dom
        |> IO.inspect(limit: :infinity, label: "Output")
        |> DataSchema.to_struct(__MODULE__)
    end
  end

  def aggregate_type(%{date: date, time: time}) do
    {:ok, date <> "T" <> time}
  end

  def string_type(val) do
    {:ok, val}
  end

  def integer_type(val) do
    {:ok, val}
  end

  def float_type(val) do
    {:ok, val}
  end

  def decimal_type(val) do
    {:ok, val}
  end
end
