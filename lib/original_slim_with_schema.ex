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

  def do_true(_original, _start_index, _end_index, {schema, acc}) do
    {schema, [true | acc]}
  end

  def do_false(_original, _start_index, _end_index, {schema, acc}) do
    {schema, [false | acc]}
  end

  def do_null(_original, _start_index, _end_index, {schema, acc}) do
    {schema, [nil | acc]}
  end

  def do_string(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    # len = end_index - 1 - (start_index + 1) + 1
    # string = :binary.part(original, start_index, len)
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON. We do no escaping as is.
    string = :binary.part(original, start_index + 1, len - 2)
    {schema, [{@string, string} | acc]}
  end

  def do_integer(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)
    {schema, [{@integer, numb} | acc]}
  end

  def do_float(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    numb = :binary.part(original, start_index, len)
    {schema, [{@float, numb} | acc]}
  end

  def start_of_object(_original, _start_index, {schema, acc}) do
    {schema, [@object_start | acc]}
  end

  def object_key(original, start_index, end_index, {schema, acc}) when start_index <= end_index do
    len = end_index - start_index + 1
    # This is to exclude the speech marks in the original JSON.
    key = :binary.part(original, start_index + 1, len - 2)
    {schema, [{@object_key, key} | acc]}
  end

  def end_of_object(_original, _start_index, {schema, acc}) do
    {schema, [@object_end | acc]}
  end

  def start_of_array(_original, _start_index, {schema, acc}) do
    {schema, [@array_start | acc]}
  end

  def end_of_array(_original, _start_index, {schema, acc}) do
    {schema, [@array_end | acc]}
  end

  def end_of_document(_original, _end_index, {_schema, acc}) do
    # Whether we reverse this or not is an interesing Q
    Enum.reverse(acc)
  end
end
