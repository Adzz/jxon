defmodule OriginalSlimWithSchema do
  @string :string
  @object_start :object_start
  @object_key :object_key
  @object_end :object_end
  @array_start :array_start
  @array_end :array_end
  @integer :integer
  @float :float

  # @string 0
  # @positive_number 1
  # @negative_number 2
  # @object_start 3
  # @object_key 4
  # @object_end 5
  # @array_start 6
  # @array_end 7

  # Likely we have to figure out if it's an object value or not. TBD
  def do_true(_original, _start_index, _end_index, {schema, acc}) do
    {schema, add_value(true, acc)}
  end

  def do_false(_original, _start_index, _end_index, {schema, acc}) do
    {schema, add_value(false, acc)}
  end

  def do_null(_original, _start_index, _end_index, {schema, acc}) do
    {schema, add_value(nil, acc)}
  end

  def do_string(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    # len = end_index - 1 - (start_index + 1) + 1
    # string = :binary.part(original, start_index, len)
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON. We do no escaping as is.
    string = :binary.part(original, start_index + 1, len - 2)
    {schema, add_value(string, acc)}
  end

  def do_integer(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)
    {schema, add_value(numb, acc)}
  end

  def do_float(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)
    {schema, add_value(numb, acc)}
  end

  def start_of_object(_original, start_index, {schema, acc}) do
    # So here we want to check that we are expecting an object? I think erroring on a type
    # difference is good but erroring on a value being missing should be handled elsewhere
    # in data_schema.
    if schema = schema.__struct__.contains?(schema, :object) do
      {schema, [%{} | acc]}
    else
      # We'd need a better error pointing exactly to the field we care about ideally.
      # Which we could get with a cheeky schema.get_current_node() or something?
      {:error, "Object found but schema did not expect one.", start_index}
    end
  end

  def object_key(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON.
    key = :binary.part(original, start_index + 1, len - 2)

    if inner = schema.__struct__.contains?(schema, key) do
      {inner, add_value({@object_key, key}, acc)}
    else
      {schema, add_value({:skip, 0}, acc)}
    end
  end

  def end_of_object(_original, _start_index, {schema, acc}) do
    # Here we have to tell the schema we are done with the object. Acc likely remains untouched
    schema = schema.__struct__.step_back_object(schema)

    case acc do
      [item] ->
        {schema, item}

      [map, list | rest_acc] when is_map(map) and is_list(list) ->
        {schema, [[map | list] | rest_acc]}

      [map, {@object_key, key}, prev_map | rest_acc] when is_map(map) and is_map(prev_map) ->
        {schema, [Map.put(prev_map, key, map) | rest_acc]}
    end
  end

  def start_of_array(_original, start_index, {schema, acc}) do
    if schema = schema.__struct__.contains?(schema, :all) do
      {schema, [[] | acc]}
    else
      {:error, "Not actually sure just yet", start_index}
    end
  end

  def end_of_array(_original, _start_index, {schema, acc}) do
    schema = schema.__struct__.step_back_array(schema)

    case acc do
      [item] ->
        {schema, item}

      [list, {@object_key, key}, map | rest_acc] when is_list(list) and is_map(map) ->
        {schema, [Map.put(map, key, Enum.reverse(list)) | rest_acc]}

      [list | rest_acc] when is_list(list) ->
        {schema, [Enum.reverse(list) | rest_acc]}
    end
  end

  def end_of_document(_original, _end_index, {_schema, acc}) do
    acc
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
