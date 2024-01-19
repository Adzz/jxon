defmodule CastingHandler do
  @moduledoc """
  """

  def do_true(_original_binary, start_index, end_index, acc) when start_index <= end_index do
    # we add 1 because the indexes are 0 indexed but length isn't.
    # len = end_index - start_index + 1
    # value = :binary.part(original_binary, start_index, len)
    update_acc(true, acc)
  end

  def do_false(_original_binary, start_index, end_index, acc) when start_index <= end_index do
    # we add 1 because the indexes are 0 indexed but length isn't.
    # len = end_index - start_index + 1
    # value = :binary.part(original_binary, start_index, len)
    update_acc(false, acc)
  end

  def do_null(_original_binary, start_index, end_index, acc) when start_index <= end_index do
    # we add 1 because the indexes are 0 indexed but length isn't.
    # len = end_index - start_index + 1
    # value = :binary.part(original_binary, start_index, len)
    update_acc(nil, acc)
  end

  def do_string(original_binary, start_index, end_index, acc) when start_index <= end_index do
    # the start and end index include the quote marks. But we can drop them for our use
    # case.
    len = end_index - 1 - (start_index + 1) + 1
    value = :binary.part(original_binary, start_index + 1, len)
    update_acc(value, acc)
  end

  def do_negative_number(original_binary, start_index, end_index, acc)
      when start_index <= end_index do
    # we add 1 because the indexes are 0 indexed but length isn't.
    len = end_index - start_index + 1
    value = :binary.part(original_binary, start_index, len)
    {v, _} = Integer.parse(value)
    update_acc(v, acc)
  end

  def do_positive_number(original_binary, start_index, end_index, acc)
      when start_index <= end_index do
    # we add 1 because the indexes are 0 indexed but length isn't.
    len = end_index - start_index + 1
    value = :binary.part(original_binary, start_index, len)
    {v, _} = Integer.parse(value)
    update_acc(v, acc)
  end

  def start_of_object(original_binary, start_index, acc) do
    if :binary.part(original_binary, start_index, 1) != "{" do
      raise "Object index error"
    end

    [%{} | acc]
    # |> IO.inspect(limit: :infinity, label: "start_of_object 1")
  end

  # In valid json this will always be a string, so likely it's the same
  # as parse string, but we let the caller decide that. Perhaps someone wants to
  # encode string keys differently. The funny thing though is we can't do anything with
  # the key until we have the value. Either the lexer has to remember the key and emit it
  # with the value or we  have to do that here.

  # Errors the lexer will catch: key and no value, invalid key, value and no key, no
  # separator, no comma, invalid chars at random places.... etc.
  def object_key(original_binary, start_index, end_index, acc) when start_index <= end_index do
    [key | _] = do_string(original_binary, start_index, end_index, acc)

    [{key, :not_parsed_yet} | acc]
    # |> IO.inspect(limit: :infinity, label: "object_key 1")
  end

  def end_of_object(original_binary, end_index, acc) do
    if :binary.part(original_binary, end_index, 1) != "}" do
      raise "Object end index error"
    end

    case acc do
      [map, list | rest] when is_list(list) ->
        [[map | list] | rest]

      # |> IO.inspect(limit: :infinity, label: "end_of_object 1")
      [value, {key, :not_parsed_yet}, map | rest] ->
        [Map.put(map, key, value) | rest]

      acc ->
        acc
        # |> IO.inspect(limit: :infinity, label: "end_of_object 2")
    end

    # Here we may have to put it into the list, right?
  end

  def start_of_array(original_binary, start_index, acc) do
    if :binary.part(original_binary, start_index, 1) != "[" do
      raise "Array index error"
    end

    [[] | acc]
    # |> IO.inspect(limit: :infinity, label: "start_of_array 1")
  end

  # If we are closing an array and the thing before it is an array we collapse into
  # that because can't have multiple arrays that don't collapse?
  def end_of_array(original_binary, end_index, [array, parent | rest])
      when is_list(array) and is_list(parent) do
    if :binary.part(original_binary, end_index, 1) != "]" do
      raise "Array index error"
    end

    [[Enum.reverse(array) | parent] | rest]
    # |> IO.inspect(limit: :infinity, label: "end_of_array 1")
  end

  def end_of_array(original_binary, end_index, [map, parent | rest]) when is_list(parent) do
    if :binary.part(original_binary, end_index, 1) != "]" do
      raise "Array index error"
    end

    [Enum.reverse([map | parent]) | rest]
    # |> IO.inspect(limit: :infinity, label: "end_of_array 2")
  end

  def end_of_array(_original_binary, _end_index, [list, {key, :not_parsed_yet}, map | rest])
      when is_map(map) do
    # if Map.has_key?(map, key) do
    # {:error, :duplicate_object_key, key}
    # else
    [Map.put(map, key, Enum.reverse(list)) | rest]
    # end

    # |> IO.inspect(limit: :infinity, label: "end_of_array 3")
  end

  def end_of_array(_original_binary, _end_index, [array]) do
    [Enum.reverse(array)]
    # |> IO.inspect(limit: :infinity, label: "4")
  end

  def end_of_document(original_binary, end_index, [acc]) do
    # This should not be out of range. It shouldn't be short either we could assert on that.
    :binary.part(original_binary, end_index, 1)
    acc
  end

  defp update_acc(value, [{key, :not_parsed_yet}, map | rest]) when is_map(map) do
    # if Map.has_key?(map, key) do
    # {:error, :duplicate_object_key, key}
    # else
    [Map.put(map, key, value) | rest]
    # end

    # |> IO.inspect(limit: :infinity, label: "update_acc 1")
  end

  defp update_acc(value, [list | rest]) when is_list(list) do
    [[value | list] | rest]
    # |> IO.inspect(limit: :infinity, label: "update_acc 2")
  end

  defp update_acc(value, acc) do
    [value | acc]
    # |> IO.inspect(limit: :infinity, label: "update_acc 3")
  end
end
