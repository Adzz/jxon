defmodule BinarySchema do
  @moduledoc """
  VERY MUCH AN UNFINISHED EXPERIMENT.
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
