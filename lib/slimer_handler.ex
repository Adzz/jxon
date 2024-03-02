defmodule SlimerHandler do
  @string :string
  @positive_number :positive_number
  @negative_number :negative_number
  @object_start :object_start
  @object_key :object_key
  @object_end :object_end
  @array_start :array_start
  @array_end :array_end
  # TODO change the above to this:
  # @string 0
  # @positive_number 1
  # @negative_number 2
  # @object_start 3
  # @object_key 4
  # @object_end 5
  # @array_start 6
  # @array_end 7

  @moduledoc """
  This is an experiment to see if we gain anything from having the stuff be one flat list
  of things. Here is an example output:

      json = "[true, false, null, 1, 2, 3, 4, 5]"

      [
        {:array_start, 0, 1},
        true,
        false,
        nil,
        {:positive_number, 20, 1},
        {:positive_number, 22, 1},
        {:positive_number, 25, 1},
        {:positive_number, 28, 1},
        {:positive_number, 31, 1},
        {:array_end, 32, 1}
      ]

  We now have to figure out a good way to ingest that and turn it into a DOM of some kind.
  Can we use schemas to filter down the data we keep? Do we have to verify it's correct.

  You might think you could store keys and values together but if you have nested objects
  or arrays then that means you tree becomes nested. Not sure if that would result in worse
  perf or not..
  """

  def handle_true(start_index, end_index, acc) when start_index <= end_index do
    [true | acc]
  end

  def handle_false(start_index, end_index, acc) when start_index <= end_index do
    [false | acc]
  end

  def handle_null(start_index, end_index, acc) when start_index <= end_index do
    [nil | acc]
  end

  def handle_string(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - 1 - (start_index + 1) + 1
    [{@string, start_index + 1, len} | acc]
  end

  # Positive and negative numbers is not the distinction we care about. It's integers
  # and floats, most likely. We should emit a fn for float and one for integer. Ergh..
  def do_negative_number(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@negative_number, start_index, len} | acc]
  end

  def do_positive_number(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@positive_number, start_index, len} | acc]
  end

  def start_of_object(_start_index, acc) do
    [@object_start | acc]
  end

  # Whilst there is a question about how we get the sub binary here like can we let the user
  # decide whether to copy the binary or not.
  def object_key(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - 1 - (start_index + 1) + 1
    # we really want the object keys stored here because we need them to search and
    # don't want to have to keep calling :binary.part ? It's like repeated work, right?
    # So either we save it here, or we have to do a pass over the instructions to fill it in
    # which seems bad because like how many times we iterating over it lmao.
    [{@object_key, start_index + 1, len} | acc]
  end

  def end_of_object(_start_index, acc) do
    [@object_end | acc]
  end

  def start_of_array(_start_index, acc) do
    [@array_start | acc]
  end

  def end_of_array(_start_index, acc) do
    [@array_end | acc]
  end

  def end_of_document(_end_index, acc) do
    # Whether we reverse this or not is an interesing Q
    Enum.reverse(acc)
  end
end
