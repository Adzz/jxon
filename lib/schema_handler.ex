defmodule SchemaHandler do
  @object_key :object_key

  @moduledoc """
  Notes:

    - because the lexer handles the correctness of object/array nesting here we don't have
      to do the same we just have to keep a count with two integers. We know we have done
      skipping once the count is == 0.

    - Currently this returns a map. What would we have to do to be able to return a struct?
    - We don't do any checks to see if something we specified in the schema was _not_ in the
      data. I guess data schema handles that, but if we were like  full pattern matching then
      yea... We'd probably not need data schema.
  """

  def handle_true(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    {schema, rest}
  end

  def handle_true(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    acc
  end

  def handle_true(_original, _start_index, _end_index, {schema, acc}) do
    {schema, add_value(true, acc)}
  end

  def handle_false(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    {schema, rest}
  end

  def handle_false(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    acc
  end

  def handle_false(_original, _start_index, _end_index, {schema, acc}) do
    {schema, add_value(false, acc)}
  end

  def handle_null(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    {schema, rest}
  end

  def handle_null(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    acc
  end

  def handle_null(_original, _start_index, _end_index, {schema, acc}) do
    {schema, add_value(nil, acc)}
  end

  def handle_string(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    {schema, rest}
  end

  def handle_string(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    acc
  end

  def handle_string(original, start_index, end_index, {schema, acc}) do
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON. We do no escaping as is.
    string = :binary.part(original, start_index + 1, len - 2)

    {schema, add_value(string, acc)}
  end

  def handle_integer(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    {schema, rest}
  end

  def handle_integer(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    acc
  end

  def handle_integer(original, start_index, end_index, {schema, acc})
      when start_index <= end_index do
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)
    {schema, add_value(numb, acc)}
  end

  def handle_float(_, _, _, {schema, [{:skip, 0, 0} | rest]}) do
    {schema, rest}
  end

  def handle_float(_, _, _, {_, [{:skip, _array_depth, _obj_depth} | _]} = acc) do
    acc
  end

  def handle_float(original, start_index, end_index, {schema, acc})
      when start_index <= end_index do
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)
    {schema, add_value(numb, acc)}
  end

  def start_of_object(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    {schema, [{:skip, array_depth, obj_depth + 1} | rest_acc]}
  end

  def start_of_object(_original, _start_index, {schema, acc}) do
    case schema.__struct__.contains?(schema, :object) do
      {inner, true} -> {inner, [%{} | acc]}
      {inner, false} -> {inner, [{:skip, 0, 1} | acc]}
    end
  end

  def object_key(_original, _start_index, _end_index, {_, [{:skip, _, _} | _]} = acc) do
    acc
  end

  def object_key(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON.
    key = :binary.part(original, start_index + 1, len - 2)

    case schema.__struct__.contains?(schema, key) do
      {inner, true} -> {inner, add_value({@object_key, key}, acc)}
      {inner, false} -> {inner, [{:skip, 0, 0} | acc]}
    end
  end

  def end_of_object(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    new_obj_depth = obj_depth - 1

    if new_obj_depth <= 0 && array_depth <= 0 do
      {schema, rest_acc}
    else
      {schema, [{:skip, array_depth, new_obj_depth} | rest_acc]}
    end
  end

  def end_of_object(_original, _start_index, {schema, acc}) do
    # Here we have to tell the schema we are done with the object. This depends on the
    # weird schema design that we have chosen here. We should really benchmark against an
    # existing zipper implementation. If the schema could be a zipper there's no reason we
    # couldn't also include the casting functions. IN FACT instead of "true" why don't we
    # just use that fns? One problem is has one / many I think.
    schema = schema.__struct__.step_back_object(schema)

    case acc do
      [map, list | rest_acc] when is_map(map) and is_list(list) ->
        {schema, [[map | list] | rest_acc]}

      [map, {@object_key, key}, prev_map | rest_acc] when is_map(map) and is_map(prev_map) ->
        {schema, [Map.put(prev_map, key, map) | rest_acc]}

      [map | rest_acc] when is_map(map) ->
        {schema, [map | rest_acc]}
    end
  end

  def start_of_array(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    {schema, [{:skip, array_depth + 1, obj_depth} | rest_acc]}
  end

  def start_of_array(_original, _start_index, {schema, acc}) do
    case schema.__struct__.contains?(schema, :all) do
      {inner, true} -> {inner, [[] | acc]}
      {inner, false} -> {inner, [{:skip, 1, 0} | acc]}
    end
  end

  def end_of_array(_, _, {schema, [{:skip, array_depth, obj_depth} | rest_acc]}) do
    new_array_depth = array_depth - 1

    if new_array_depth <= 0 && obj_depth <= 0 do
      # Do we need to reverse here? I dont think so because we must have started skipping
      # on the open of the array or would have been skipping then already.
      {schema, rest_acc}
    else
      {schema, [{:skip, new_array_depth, obj_depth} | rest_acc]}
    end
  end

  def end_of_array(_original, _start_index, {schema, acc}) do
    schema = schema.__struct__.step_back_array(schema)

    case acc do
      [list, {@object_key, key}, map | rest_acc] when is_list(list) and is_map(map) ->
        {schema, [Map.put(map, key, Enum.reverse(list)) | rest_acc]}

      [item, list | rest_acc] when is_list(list) and is_list(item) ->
        {schema, [[Enum.reverse(item) | list] | rest_acc]}

      [list | rest_acc] when is_list(list) ->
        {schema, [Enum.reverse(list) | rest_acc]}
    end
  end

  def end_of_document(_original, _end_index, {_schema, [acc]}) do
    acc
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
