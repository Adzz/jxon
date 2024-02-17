defmodule BinarySchema do
  @moduledoc """
  This one is an experiment to see if we can / if it's better to use a binary and pattern
  matching "skip" shenanigans to encode the schema. The way it works is the binary is made
  up of a map key, then a number which will represent how many ancestors it has. This is
  then used to know how many to skip to get to its sibling in the tree (ie the next map
  key). Because it's a stack the next "level" down, ie the children are always + 1.

  Let's sketch an example:

      { "a" => { "b"=> 1 }, "c" => 2}

  {"a"6{"b"0}"c"0}

  the number after the "a" (6) needs to be the number of chars to skip, so it will depend on
  the length of the keys in all its descendants. In this simple example we are skipping
  "b"0 because b key has no siblings.

  Another example:

        {
        "has_many": [
          { "ignored": "key", "first_key": "eat more water" },
          { "first_key": "drink more food", "ignored": "key" }
        ]
      }

  {"has_many"0["first_key"0]}

  Now how do we iterate. We try and match the first key. If that fails we get up to : or "
  then we the use the number we pull out to skip.

    # To know how many items to skip we need to now where the next sibling is. Which
    # means extracting that count. We do that by skipping up until a " then getting
    # everything up until the next one. We could make this simpler by putting the number
    # first? Then we'd just extract up until the first ". But then we'd have the problem
    # of not knowing how many digits there are. You could maybe get away with a fixed number
    # of integers and just not allow larger numbers. Don't hate this, especially if you used
    # hex codes because there is an upper bound on it somewhere I presume. we could represent
    # quite a large number. I'm sure there would be a way to be quite clever here when we
    # generate the schema, because at that point we'll know how deep and wide the tree is
    # and how long the objects keys are. For long schema we could use hexcodes or something
    # essentially you could pick the minimum digit size needed in hex to represent the
    # largest skip index needed. Then if you saved that on the schema struct you could
    # have these functions refer to it to pull off the number from the begining. That
    # would make it nice and easy to get to the right stuff. Would mean bloat if you had
    # one really long key with lots of children. But.. probs fine? who knows.
    # ALTERNATIVELY. we could
    # have the numbers exist in a different data structure? likely this devolves into having
    # the schema be a stack. But because we can't truly skip entries in a list then the
    # whole thing becomes a but pointless I suspect.
    # Failing all of that we need to skip until we see the thing we care about, return indexes
    # for that then :binary.part the things we care about.
  """
  # Will probably refactor the keys soon as maybe collection_type can just be current.
  defstruct [:schema, :current, :previous, :collection_type]
  @quotation_mark <<0x22>>
  @digits [
    <<0x31>>,
    <<0x32>>,
    <<0x33>>,
    <<0x34>>,
    <<0x35>>,
    <<0x36>>,
    <<0x37>>,
    <<0x38>>,
    <<0x39>>
  ]
  @zero <<0x30>>
  @all_digits [@zero | @digits]

  def contains?(%{schema: schema, current: current} = schema_struct, key) do
    # This excludes the speechmarks as they wont be present in the key we get passed.
    schema_key = :binary.part(schema, current + 1, byte_size(key))

    if schema_key == key do
      raise "FOUND"
      # Okay so we matched. Now we need to increment to the end of it. If it has children
      # then they need to be the next thing in line, otherwise the siblings do. But I guess
      # we need to know if we are seeing siblings or children because

      # We need to know if the schema is now pointing at a child or a sibling. BECAUSE
      # we need to know if that expectation is violated. So how can we track that information
      # WELL..... actually can't this happen in the other schema if a child is the same
      # as a sibling. We could mistakenly include it when we don't actually want to.

      # ALSO we need to know if we wrap to start the search from the first sibling again
      # Or each search needs to start from the first sibling everytime. There are tradeoffs
      # here. It would be great if we did not search for siblings we have already seen.
      # It's also hard to know whether searching from the first sibling everytime will
      # cost us. Because it's a binary which refers to itself chopping and changing it is
      # not going to be coat effective or easy. So instead we should first just try to
      # get it working by searching from the start each time?
    else
      # Right so here we actually have to check all siblings. Becauseeeeeee that's like the
      # whole thing. BUT I also suppose we only need to check for siblings if we are "in"
      # an object, So how do we know we are in an object? Current points to a '}' ? I
      # think we could do that. And the same for an array. we are always inside one of
      # those in reality. When we open an object in the event we progress that pointer
      # So if we are in an object then we check for siblings but if not then like
      if schema_struct.collection_type == "{" do
        check_siblings(schema_struct, key)
      else
        # If we are in an array then there are no siblings for now. Eventually you may
        # want to allow the schema to specify which index in the array to keep. If so you would
        # do that here by letting the schema have ints and checking the int here. but we
        # don't allow that yet.
        false
      end
    end
  end

  defp check_siblings(schema_struct, key) do
    <<_skip::binary-size(schema_struct.current), @quotation_mark, rest::binary>> =
      schema_struct.schema

    {start, end_index} = step_to_sibling(rest, schema_struct.current + 1)
    len = end_index - start + 1
    count_to_sibling = :binary.part(schema_struct.schema, start, len) |> String.to_integer()
    contains?(%{schema_struct | current: end_index + count_to_sibling + 1}, key)
  end

  defp step_to_sibling(<<@quotation_mark, rest::binary>>, index) do
    number_end_index = extract_number(rest, index + 1)
    {index + 1, number_end_index}
  end

  defp step_to_sibling(<<_head::binary-size(1), rest::binary>>, index) do
    step_to_sibling(rest, index + 1)
  end

  for digit <- @all_digits do
    defp extract_number(<<unquote(digit), rest::bits>>, index) do
      extract_number(rest, index + 1)
    end
  end

  # We minus 1 because we have to go one step too far to know when the number ends
  defp extract_number(<<_rest::binary>>, index), do: index - 1
end

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
    the_schema = if is_nil(schema.current), do: schema.schema, else: schema.current

    case schema.path_prefix do
      [{:everything, count} | rest] ->
        # IE if we are opening an array then increment. Do we do this for objects too?
        # well... no? I dont know?
        if key == :all || key == :object do
          {%{schema | path_prefix: [{:everything, count + 1} | rest]}, true}
        else
          {schema, true}
        end

      prefix ->
        # When we are opening an array we need to increment count. So we need to know if the
        # path prefix has that in it?
        case Map.get(the_schema, key) do
          true -> {schema, true}
          # If the schema returns this then it's like "turn everything off". Great. BUT
          # we then need to track if we open an array again. Where/when does that happen. Not
          # here probs because there wont be a schema to check I think we need to case on the
          # path prefix
          :everything -> {%{schema | path_prefix: [{:everything, 0} | prefix]}, true}
          nil -> {schema, false}
          inner -> {%{schema | current: inner, path_prefix: [key | schema.path_prefix]}, true}
        end
    end
  end

  def step_back_array(schema) do
    case schema.path_prefix do
      [{:everything, count} | rest_prefix] when count > 0 ->
        %{schema | path_prefix: [{:everything, count - 1} | rest_prefix]}

      [{:everything, 0}, _key_or_all | rest_prefix] ->
        # IF we are no longer skipping everything then the last array must have closed SO
        # we also nee to chunk off the :all I think. WELL not the :all but whatever we
        # are inside of, which could be :all OR an object, IE an object key I think.
        %{schema | path_prefix: rest_prefix}

      [{:everything, 0}] ->
        %{schema | current: schema.schema, path_prefix: []}

      # OBJECT INSIDE ARRAY
      [:object | [:all | _] = rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      # ARRAY INSIDE ARRAY
      [:all | [:all | _] = rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      # ARRAY INSIDE OBJECT
      [:all, _object_key | [:object | _] = rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      # ARRAY ON ITS OWN
      [:all] ->
        %{schema | current: schema.schema, path_prefix: []}
    end
  end

  # When we close an object we need to know whether we keep the schema there which we do
  # if we are in an array. Which should mean if :all is in the path?
  @doc """
  What does it mean to step back? simply we must drop a key off of the path and then apply
  it. So let's take some simple examples:

  ["a", :object]
  %{ "a" =>}
  """
  def step_back_object(schema) do
    case schema.path_prefix do
      # OBJECT IN ARRAY
      [:object | [:all | _] = rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      # OBJECT IN OBJECT
      [:object, _object_key | [:object | _] = rest_prefix] ->
        rest_schema = get_in(schema.schema, Enum.reverse(rest_prefix))
        %{schema | current: rest_schema, path_prefix: rest_prefix}

      # OBJECT ON ITS OWN
      [:object] ->
        %{schema | current: schema.schema, path_prefix: []}

      [:all] ->
        %{schema | current: schema.schema, path_prefix: []}
    end
  end
end
