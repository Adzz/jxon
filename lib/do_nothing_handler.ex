defmodule DoNothingHandler do
  # Feel like this would use less mems.
  @string 3
  @positive_number 4
  @negative_number 5
  @object_start 6
  @object_key 7
  @object_end 8
  @array_start 9
  @array_end 10

  def do_true(_start_index, _end_index, acc) do
    [true | acc]
  end

  def do_false(_start_index, _end_index, acc) do
    [false | acc]
  end

  def do_null(_start_index, _end_index, acc) do
    [nil | acc]
  end

  def do_string(start_index, end_index, acc) do
    len = end_index - 1 - (start_index + 1) + 1
    [{@string, start_index + 1, len} | acc]
  end

  def do_negative_number(start_index, end_index, acc) do
    len = end_index - start_index + 1
    [{@negative_number, start_index, len} | acc]
  end

  def do_positive_number(start_index, end_index, acc) do
    len = end_index - start_index + 1
    [{@positive_number, start_index, len} | acc]
  end

  def start_of_object(_start_index, acc) do
    [@object_start | acc]
  end

  def object_key(start_index, end_index, acc) do
    len = end_index - 1 - (start_index + 1) + 1
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
    acc
  end
end
