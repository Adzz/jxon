defmodule OriginalSlimWithSchema do
  @object_key :object_key

  @moduledoc """
  Notes:

    - because the lexer handles the correctness of object/array nesting here we don't have
      to do the same we just have to keep a count with two integers. We know we have done
      skipping once the count is == 0.

  """

  def do_true(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    # dbg()

    {schema, rest}
    # |> dbg()
  end

  def do_true(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def do_true(_original, _start_index, _end_index, {schema, acc}) do
    # dbg()

    {schema, add_value(true, acc)}
    # |> dbg()
  end

  def do_false(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    # dbg()

    {schema, rest}
    # |> dbg()
  end

  def do_false(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def do_false(_original, _start_index, _end_index, {schema, acc}) do
    # dbg()

    {schema, add_value(false, acc)}
    # |> dbg()
  end

  def do_null(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    # dbg()

    {schema, rest}
    # |> dbg()
  end

  def do_null(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def do_null(_original, _start_index, _end_index, {schema, acc}) do
    # dbg()

    {schema, add_value(nil, acc)}
    # |> dbg()
  end

  def do_string(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    # dbg()

    {schema, rest}
    # |> dbg()
  end

  def do_string(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def do_string(original, start_index, end_index, {schema, acc}) do
    # dbg()
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON. We do no escaping as is.
    string = :binary.part(original, start_index + 1, len - 2)

    {schema, add_value(string, acc)}
    # |> dbg()
  end

  def do_integer(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    # dbg()

    {schema, rest}
    # |> dbg()
  end

  def do_integer(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def do_integer(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    # dbg()
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)

    {schema, add_value(numb, acc)}
    # |> dbg()
  end

  def do_float(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    # dbg()

    {schema, rest}
    # |> dbg()
  end

  def do_float(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def do_float(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    # dbg()
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)

    {schema, add_value(numb, acc)}
    # |> dbg()
  end

  def start_of_object(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    # dbg()

    {schema, [{:skip, array_depth, obj_depth + 1} | rest_acc]}
    # |> dbg()
  end

  def start_of_object(_original, _start_index, {schema, acc}) do
    # dbg()

    # Probably a better return value is just  {schema, boolean}
    # Then we lose a case.
    case schema.__struct__.contains?(schema, :object) do
      {inner, true} -> {inner, [%{} | acc]}
      {inner, false} -> {inner, [{:skip, 0, 1} | acc]}
    end

    # |> dbg()
  end

  def object_key(_original, _start_index, _end_index, {_, [{:skip, _, _} | _]} = acc) do
    # dbg()

    acc
    # |> dbg()
  end

  def object_key(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    # dbg()
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON.
    key = :binary.part(original, start_index + 1, len - 2)
    # key |> dbg()

    case schema.__struct__.contains?(schema, key) do
      {inner, true} -> {inner, add_value({@object_key, key}, acc)}
      {inner, false} -> {inner, [{:skip, 0, 0} | acc]}
    end

    # |> dbg()
  end

  def end_of_object(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    # dbg()
    new_obj_depth = obj_depth - 1

    if new_obj_depth <= 0 && array_depth <= 0 do
      {schema, rest_acc}
    else
      {schema, [{:skip, array_depth, new_obj_depth} | rest_acc]}
    end

    # |> dbg()
  end

  def end_of_object(_original, _start_index, {schema, acc}) do
    # dbg()
    # Here we have to tell the schema we are done with the object.
    schema = schema.__struct__.step_back_object(schema)

    case acc do
      [map, list | rest_acc] when is_map(map) and is_list(list) ->
        {schema, [[map | list] | rest_acc]}

      [map, {@object_key, key}, prev_map | rest_acc] when is_map(map) and is_map(prev_map) ->
        {schema, [Map.put(prev_map, key, map) | rest_acc]}

      [map | rest_acc] when is_map(map) ->
        {schema, [map | rest_acc]}
    end

    # |> dbg()
  end

  def start_of_array(_, _, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    # dbg()

    {schema, [{:skip, array_depth + 1, obj_depth} | rest_acc]}
    # |> dbg()
  end

  def start_of_array(_original, _start_index, {schema, acc}) do
    # dbg()

    case schema.__struct__.contains?(schema, :all) do
      {inner, true} -> {inner, [[] | acc]}
      {inner, false} -> {inner, [{:skip, 1, 0} | acc]}
    end

    # |> dbg()
  end

  def end_of_array(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    # dbg()
    new_array_depth = array_depth - 1

    if new_array_depth <= 0 && obj_depth <= 0 do
      # Do we need to reverse here? I dont think so because we must have started skipping
      # on the open of the array or would have been skipping then already.
      {schema, rest_acc}
    else
      {schema, [{:skip, new_array_depth, obj_depth} | rest_acc]}
    end

    # |> dbg()
  end

  def end_of_array(_original, _start_index, {schema, acc}) do
    # dbg()
    schema = schema.__struct__.step_back_array(schema)

    case acc do
      [list, {@object_key, key}, map | rest_acc] when is_list(list) and is_map(map) ->
        {schema, [Map.put(map, key, Enum.reverse(list)) | rest_acc]}

      [item, list | rest_acc] when is_list(list) and is_list(item) ->
        {schema, [[Enum.reverse(item) | list] | rest_acc]}

      [list | rest_acc] when is_list(list) ->
        {schema, [Enum.reverse(list) | rest_acc]}
    end

    # |> dbg()
  end

  def end_of_document(_original, _end_index, {_schema, [acc]}) do
    # dbg()

    acc
    # |> dbg()
  end

  def end_of_document(_original, _end_index, {_schema, []}) do
    {:error, :empty_document}
  end

  defp add_value(value, [list | rest_acc]) when is_list(list) do
    [[value | list] | rest_acc]
  end

  defp add_value(value, [{@object_key, key}, map | rest_acc]) when is_map(map) do
    [Map.put(map, key, value) | rest_acc]
  end

  defp add_value(value, acc) do
    [value | acc]
  end
end
