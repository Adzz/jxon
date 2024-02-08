defmodule Schema do
  @moduledoc """
  An experimental module to let us iterate on what a good data structure would look like
  for querying paths when we parse the JSON.

  Some early thoughts are that we could maybe use a flat array and do like pointer/index
  math to figure out how many we have to jump in order to find a sibling.
  This might require a couple of passes when generating the schema paths but that's fine.

  Another option is to just try using an existing zipper lib?
  Another option is to try nested maps that we take apart and put back together again?


  This is the example we will rock with for now:

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
        "has_many": [
          { "first_key": "eat more water" },
          { "first_key": "drink more food" }
        ]
      }


  So let's first design a schema that works for finding all the paths in it.
  I think we could make it work with a zipper. But 3d tree zippers are hard to get your
  head around and I'm not convinced they would be particularly efficient. In a language with
  actual arrays I really feel like it would be possible to use them and do interesting pointer
  math. We are going to try and do the same thing here.

  Would a map be good. Perhaps we can have a blend of both. The map for the siblings.
  Then we can track keys and levels

  [
    %{
      "name" =>  true,
      "integer" => true,
      "float" => true,
      "decimal" => true,
      "string" => true,
      "list" => %{:all => true},
      "aggregate" => %{
        "date" =>  true,
        "time" =>  true
      },
      "has_many" => %{
        :all => true,
        0 => true
      }
    }
  ]

  So in our JSON we will see each of the keys and that should be relatively undramatic.
  Then for aggregate we are going to answer with the date/time map. How do we "go back up"
  once done?

  Well we could track the path taken to get here so far? ["aggregate"]. Then "going
  back up" is dropping a key from the end of the path. If the path is empty it's the start.
  Essentially we would be keeping track of ancestors I think.

  Few things I don't like here. One dropping things from the ends of lists is bad for large
  lists also means we are appending to a list to create our index. So that's not great. Also
  means we are always querying right from the top? Or well only when we move back up one
  I suppose. But still doesn't seem amazing. I think it is nice that we are using maps though
  as access is like random.

  There is this weirdness with lists though, do we query for :all ? or the specific index
  kind of have to check both, which means the number of checks you do grows with nesting in
  a non good way I think.

  I guess actually if we ever see :all then we don't also have to check integers, because
  we are always including the element anyway. If something else also wants the Nth element
  that's okay because we are definitely including it. If :all is not there then we have to
  check every index.

  Ahh wait, having it be a flat stack actually means we can make it a 2d zipper. then
  stepping back up is a case of usual zipper things. We could probably then also figure out
  when / if we could drop whole sections of the schema completely, like if we are done with
  a subtree then get rid, but if we are still in a list then keep it.


  Another thought. The kind of traversal we want to do is, find the element in the siblings
  then return its children. Then repeat. But we want to be able to back track.

  """
  # Not actually sure that this is a good idea. But for now the way we are "remembering"
  # is by storing a path of ancestors and then applying that to the source data to return
  # back up. It definitely feels bad man. But... it's simpler to think about?
  defstruct([:schema, :current, path_prefix: []])

  def contains?(schema, key) do
    # schema |> IO.inspect(limit: :infinity, label: "b4")
    # key |> IO.inspect(limit: :infinity, label: "contains key")
    the_schema = if is_nil(schema.current), do: schema.schema, else: schema.current

    case Map.get(the_schema, key) do
      true -> schema
      nil -> false
      inner -> %{schema | current: inner, path_prefix: [key | schema.path_prefix]}
    end
  end

  def step_back_array(schema) do
    case schema.path_prefix do
      [] ->
        %{schema | current: schema.schema, path_prefix: []}

      [:object] ->
        rest_schema = schema.schema
        %{schema | current: rest_schema, path_prefix: []}

      [:all, _item | rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      # [:object, _item | rest_prefix] ->
      #   rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
      #   %{schema | current: rest_schema, path_prefix: rest_prefix}

      [_item | rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}
    end
  end

  # When we close an object we need to know whether we keep the schema there which we do
  # if we are in an array. Which should mean if :all is in the path?
  def step_back_object(schema) do
    case schema.path_prefix do
      [] ->
        %{schema | current: schema.schema, path_prefix: []}

      [_item, :all | rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse([:all | rest_prefix]))
        %{schema | current: rest_schema, path_prefix: [:all | rest_prefix]}

      [:object, _item | rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      [_item] ->
        %{schema | current: schema.schema, path_prefix: []}

      [_item | rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}
    end
  end
end
