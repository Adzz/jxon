defmodule SlimHandler do
  # Feel like this would use less mems.
  # @true_ 0
  # @false_ 1
  # @null_ 2
  # @string 3
  # @positive_number 4
  # @negative_number 5
  # @object_start 6
  # @object_key 7
  # @object_end 8
  # @array_start 9
  # @array_end 10

  @true_ :t
  @false_ :f
  @null_ :n
  @string :string
  @positive_number :positive_number
  @negative_number :negative_number
  @object_start :object_start
  @object_key :object_key
  @object_end :object_end
  @array_start :array_start
  @array_end :array_end

  @moduledoc """
  This is an experiment to see if we gain anything from having the stuff be one flat list
  of things. Here is an example output:

      json = "[true, false, null, 1, 2, 3, 4, 5]"

      [
        {:array_start, 0, 1},
        {:t, 1, 4},
        {:f, 7, 5},
        {:n, 14, 4},
        {:positive_number, 20, 1},
        {:positive_number, 22, 1},
        {:positive_number, 25, 1},
        {:positive_number, 28, 1},
        {:positive_number, 31, 1},
        {:array_end, 32, 1}
      ]

  We now have to figure out a good way to ingest that and turn it into a DOM of some kind.
  Can we use schemas to filter down the data we keep? Do we have to verify it's correct.
  """

  def handle_true(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@true_, start_index, len} | acc]
  end

  def handle_false(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@false_, start_index, len} | acc]
  end

  def handle_null(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@null_, start_index, len} | acc]
  end

  def handle_string(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - 1 - (start_index + 1) + 1
    [{@string, start_index, len} | acc]
  end

  def do_negative_number(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@negative_number, start_index, len} | acc]
  end

  def do_positive_number(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@positive_number, start_index, len} | acc]
  end

  def start_of_object(start_index, acc) do
    [{@object_start, start_index, 1} | acc]
  end

  def object_key(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - 1 - (start_index + 1) + 1
    [{@object_key, start_index + 1, len} | acc]
  end

  def end_of_object(start_index, acc) do
    [{@object_end, start_index, 1} | acc]
  end

  def start_of_array(start_index, acc) do
    [{@array_start, start_index, 1} | acc]
  end

  def end_of_array(start_index, acc) do
    [{@array_end, start_index, 1} | acc]
  end

  def end_of_document(_end_index, acc) do
    Enum.reverse(acc)
  end
end
