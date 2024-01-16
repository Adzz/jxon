defmodule JxonIndexesTest do
  use ExUnit.Case

  defmodule TestHandler do
    @moduledoc """
    TODO eventually experiment with generating a flat list (:array) of values in the source
    and see if it's efficient to whip through the list to extract values. Need to think about
    how to flatten nested data but I kind of think you just add a 3rd dimension which is like
    jump - how many lines to jump to get to the Nth element.... Would love to play with this.
    """

    def do_true(original_binary, start_index, end_index, acc) when start_index <= end_index do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_false(original_binary, start_index, end_index, acc) when start_index <= end_index do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_null(original_binary, start_index, end_index, acc) when start_index <= end_index do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
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
      update_acc(value, acc)
    end

    def do_positive_number(original_binary, start_index, end_index, acc)
        when start_index <= end_index do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
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

  describe "bare values" do
    @describetag :values
    test "an invalid bare value whitespace" do
      json_string = "    banana  "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == "b"
    end

    test "just space is an error..." do
      json_string = " "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :empty_document, 1}
    end

    test "an invalid bare value" do
      json_string = "banana"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 0}

      assert :binary.part(json_string, 0, 1) == "b"
    end

    test "an invalid bare value after a valid one" do
      json_string = "true banana"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 5}

      assert :binary.part(json_string, 5, 1) == "b"
    end

    test "bare values surrounded by white space works" do
      json_string = " \t \n \r false  \t \n \r  "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "false"

      json_string = "  \t \n \r  true  \t \n \r  "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "true"

      json_string = "  \t \n \r  null  \t \n \r  "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "null"
    end

    test "invalid multiple bare values with whitespace" do
      json_string = "    false  true  "
      # What is a good error message here? Pointing to the part that went wrong is probably
      # good, but might be hard for large strings?
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 11}

      assert :binary.part(json_string, 11, 1) == "t"

      json_string = "  \t \n \r  true  \t \n \r  false   \t \n \r   "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 22}

      assert :binary.part(json_string, 22, 1) == "f"

      json_string = "  \t \n \r  null  \t \n \r  true   \t \n \r  "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 22}

      assert :binary.part(json_string, 22, 1) == "t"
    end

    test "invalid multiple bare values with whitespace and nested errors" do
      json_string = "  \t \n \r  false   \t \n \r   tru   \t \n \r   "
      # What is a good error message here? Pointing to the part that went wrong is probably
      # good, but might be hard for large strings?
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 25}

      assert :binary.part(json_string, 25, 1) == "t"
    end

    test "multiple bare values starting with true" do
      json_string = "   \t \n \r     true    \t \n \r   flse    \t \n \r  "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 29}

      assert :binary.part(json_string, 29, 1) == "f"

      json_string = "  \t \n \r      null    \t \n \r    rue  \t \n \r  "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 30}

      assert :binary.part(json_string, 30, 1) == "r"
    end

    test "invalid multiple bare values and nested errors" do
      json_string = "false tru"
      # What is a good error message here? Pointing to the part that went wrong is probably
      # good, but might be hard for large strings?
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 6}

      assert :binary.part(json_string, 6, 1) == "t"

      json_string = "true:flse"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ":"

      json_string = "null,rue"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end

    test "invalid multiple bare values" do
      json_string = "false true"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 6}

      assert :binary.part(json_string, 6, 1) == "t"

      json_string = "true:false"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ":"

      json_string = "null,true"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end
  end

  describe "negative numbers" do
    @describetag :neg_ints
    test "parsing negative numbers is good and fine" do
      json_string = "-1"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-1"

      json_string = "-10920394059687"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-10920394059687"
    end

    test "negative with whitespace is wrong" do
      json_string = "- 1"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 0}

      assert :binary.part(json_string, 0, 1) == "-"
    end

    test "negative sign only is wrong" do
      json_string = "-"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 0}

      assert :binary.part(json_string, 0, 1) == "-"
    end

    test "int with error chars after" do
      json_string = "-1;"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 2}

      assert :binary.part(json_string, 2, 1) == ";"
    end

    test "int with exponent" do
      json_string = "-1e40  "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-1e40"
    end

    test " 2.e3 is an error" do
      json_string = "2.e3  "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_decimal_number, 2}

      assert :binary.part(json_string, 2, 1) == "e"
    end

    test " 2. is an error" do
      json_string = "2.    "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_decimal_number, 2}

      assert :binary.part(json_string, 2, 1) == " "
    end

    test " 2.+ is an error" do
      json_string = "2.+    "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_decimal_number, 2}

      assert :binary.part(json_string, 2, 1) == "+"
    end

    test "+ve int with exponent" do
      json_string = "1e40  "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1e40"
    end

    test "int with capital exponent" do
      json_string = "-1E40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-1E40"
    end

    test "int with positive exponent" do
      json_string = "-11e+2"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-11e+2"

      json_string = "-11E+2"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-11E+2"
    end

    test "double e is wrong" do
      json_string = "-11eE+2"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_exponent, 4}

      assert :binary.part(json_string, 4, 1) == "E"

      json_string = "-11Ee+2"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_exponent, 4}

      assert :binary.part(json_string, 4, 1) == "e"
    end

    test "letter is wrong" do
      json_string = "-11eEa2"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_exponent, 4}
    end

    test "negative decimal" do
      json_string = "-1.5"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-1.5"
    end

    test "leading 0s are not allowed negative decimal" do
      json_string = "-01.5"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :leading_zero, 1}

      assert :binary.part(json_string, 1, 1) == "0"
    end

    test "leading 0s are not allowed -ve int" do
      json_string = "-0001"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :leading_zero, 1}

      assert :binary.part(json_string, 1, 1) == "0"
    end

    test "white space for a bare value is no invalid" do
      json_string = "-1.5   \n \t \r"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-1.5"
    end

    test "invalid int" do
      json_string = "-1.5;"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}
    end

    test "multiple bare values is wrong -ve ints" do
      json_string = "-1 -2 3 4 5"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 3}

      assert :binary.part(json_string, 3, 1) == "-"
    end

    test "multiple bare values is wrong -ve ints invalid char" do
      json_string = "-1.2 b -2.3 \n\t\r"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 5}

      assert :binary.part(json_string, 5, 1) == "b"
    end

    test "multiple bare values is wrong -ve ints whitespace" do
      json_string = "-1.2\n-2.3 \n\t\r"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 5}

      assert :binary.part(json_string, 5, 1) == "-"
    end
  end

  describe "positive numbers" do
    @describetag :pos_ints
    test "numbers with 0s in" do
      json_string = "102030405060708099887654321"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "102030405060708099887654321"
    end

    test "we can parse a number" do
      json_string = "1"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1"
    end

    test "we can parse a float" do
      json_string = "1.500"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1.500"
    end

    test "errors for +ve integer" do
      json_string = "1;"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == ";"
    end

    test "0 is allowed" do
      json_string = "0"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "0"
    end

    test "0exp is allowed" do
      json_string = "0e1"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "0e1"
    end

    test "0exp + is allowed" do
      json_string = "0e+1"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "0e+1"
    end

    test "0exp - is allowed" do
      json_string = "0e-1"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "0e-1"
    end

    test "0exp error is allowed" do
      json_string = "0e"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :invalid_exponent, 2}
    end

    test "-0 is allowed" do
      json_string = "-0"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "-0"
    end

    test "errors for +ve float" do
      json_string = "1.5;"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 3}

      assert :binary.part(json_string, 3, 1) == ";"
    end

    test "exponents" do
      json_string = "1.5e+40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1.5e+40"

      json_string = "1.5e-40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1.5e-40"

      json_string = "1.5E+40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1.5E+40"

      json_string = "1.5E-40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1.5E-40"

      json_string = "15e+40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "15e+40"

      json_string = "15e-40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "15e-40"

      json_string = "15E+40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "15E+40"

      json_string = "15E-40"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "15E-40"

      json_string = "15ee+40"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_exponent, 3}

      assert :binary.part(json_string, 3, 1) == "e"
    end

    test "exponent error no number after e" do
      json_string = "15e"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_exponent, 3}
    end

    test "exponent error no number after E" do
      json_string = "15E"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_exponent, 3}
    end

    test "leading 0s" do
      json_string = "001"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :leading_zero, 0}
      json_string = "01.5"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :leading_zero, 0}

      assert :binary.part(json_string, 0, 1) == "0"
    end

    test "multiple bare values is wrong" do
      json_string = "1 2 3 4 5"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 2}

      assert :binary.part(json_string, 2, 1) == "2"
    end

    test "multiple with a decimal number" do
      json_string = "1.2 . 2.3 \n\t\r"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == "."
    end

    test "multiple decimals" do
      json_string = "1.2\n2.3 \n\t\r"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 4}

      assert :binary.part(json_string, 4, 1) == "2"
    end
  end

  describe "strings" do
    @describetag :strings
    test "basic string" do
      # These string escapes are for Elixir not JSON, so the parser just sees it as
      # "[1,2,3,4]"
      json_string = "\"[1, 2, 3, 4]\""
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "[1, 2, 3, 4]"
    end

    test "escaped quotation mark in string" do
      json_string = File.read!("/Users/Adz/Projects/jxon/test/fixtures/escapes_string.json")
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               "this is what he said: \\\"no\\\""
    end

    test "single backslash is not an error because we are just passing through the raw string as is" do
      acc = []
      json_string = ~s("\\ ")
      # This would be an error you would handle and implement in the callback where you did
      # string escaping.
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\ "
    end

    test "When the string is not terminated we error" do
      acc = []
      json_string = ~s("\\")

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unterminated_string, 2}

      assert :binary.part(json_string, 2, 1) == "\""
    end

    test ~s("\\"\\\\\\/\\b\\f\\n\\r\\t") do
      acc = []
      json_string = ~s("\\"\\\\\\/\\b\\f\\n\\r\\t")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\\"\\\\\\/\\b\\f\\n\\r\\t"
    end

    test "unicode escapes don't actually escape, they just return as is" do
      # This enables JCS
      acc = []
      json_string = ~s("\\u2603")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\u2603"
      json_string = ~s("\\u2028\\u2029")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\u2028\\u2029"
      json_string = ~s("\\uD834\\uDD1E")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\uD834\\uDD1E"
      json_string = ~s("\\uD834\\uDD1E")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\uD834\\uDD1E"
      json_string = ~s("\\uD799\\uD799")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "\\uD799\\uD799"
      json_string = ~s("✔︎")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "✔︎"
    end

    test "multiple strings when there shouldn't be" do
      acc = []
      json_string = ~s("this is valid " "this is not!")

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 17}

      assert :binary.part(json_string, 17, 1) == "\""
    end

    test "a string with numbers in it works" do
      acc = []
      json_string = ~s(" one 1 two 2 ")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == " one 1 two 2 "
    end

    test "numbers in a string all having fun" do
      acc = []
      json_string = ~s("1,2,3,4,5,6")
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "1,2,3,4,5,6"
    end
  end

  describe "arrays" do
    @describetag :arrays
    test "open array whitespace and an error is an error" do
      json_string = "[ b "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 2}

      assert :binary.part(json_string, 2, 1) == "b"
    end

    test "open array and an error is an error" do
      json_string = "[b "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == "b"
    end

    test "empty array" do
      json_string = "[]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == []
    end

    test "array of one number" do
      json_string = "[1]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["1"]
    end

    test "array of one number trialing comma" do
      json_string = "[1,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :trailing_comma, 2}
    end

    test "array of string" do
      json_string = "[\"1\"]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["1"]
    end

    test "array of boolean and nil" do
      json_string = "[true, false, null]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["true", "false", "null"]
    end

    test "nested stuff" do
      json_string = "[[true, []], [[\"a\",false,\"b\"\n\t\r], [1, null, 2.50, 112.2, 8]]]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == [
               ["true", []],
               [["a", "false", "b"], ["1", "null", "2.50", "112.2", "8"]]
             ]
    end

    # Error cases as I think of them.
    test "unclosed array" do
      json_string = "[1"
      acc = []

      assert {:error, :unclosed_array, index} =
               JxonIndexes.parse(json_string, TestHandler, 0, acc)

      assert index == 1
      assert :binary.part(json_string, index, 1) == "1"
    end

    test "multiple non comma'd elements" do
      json_string = "[1 2]"
      acc = []

      assert {:error, :multiple_bare_values, index} =
               JxonIndexes.parse(json_string, TestHandler, 0, acc)

      assert index == 3
      assert :binary.part(json_string, index, 1) == "2"
    end

    test "unclosed multiple non comma'd elements" do
      json_string = "[1 2"
      acc = []

      assert {:error, :multiple_bare_values, index} =
               JxonIndexes.parse(json_string, TestHandler, 0, acc)

      assert index == 3
      assert :binary.part(json_string, index, 1) == "2"
    end

    test "just commas" do
      json_string = "[,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :leading_comma, 1}
      assert :binary.part(json_string, 1, 1) == ","
    end

    test "double comma" do
      json_string = "[1,,,,,,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :double_comma, 3}
      assert :binary.part(json_string, 3, 1) == ","
    end

    test "leading_comma comma" do
      json_string = "[,,,,,,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :leading_comma, 1}
      assert :binary.part(json_string, 1, 1) == ","
    end

    test "unclosed trailing comma" do
      json_string = "[1,2  , "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :unclosed_array, 7}
      assert :binary.part(json_string, 7, 1) == " "
    end

    test "trailing comma [1,2,] " do
      json_string = "[1,2,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :trailing_comma, 4}
      assert :binary.part(json_string, 4, 1) == ","
    end

    # NESTING
    test "nested array" do
      json_string = "[[]]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == [[]]
    end

    test "nested unclosed array" do
      json_string = "[[]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :unclosed_array, 2}
      assert :binary.part(json_string, 2, 1) == "]"
    end

    test "multiple nested array" do
      json_string = "[[], [1, [3]]]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == [[], ["1", ["3"]]]
    end

    test "nested with whitespace" do
      json_string = "[ [  \n\t ]\n\t\r,[  ] ]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == [[], []]
    end

    test "unclosed array in an object" do
      # json_string = "{ "A": [ ], "B": [ [ true ], "thing": [] }"
      # json_string = "{ "A": [ ], "B": [ [ true ] }"
      # json_string = "{ "A": [ ], "B": [ [ true ] , }"
      # json_string = "[ [ true ] , [,  "
      json_string = "[ [ true ] , [ ] "
      # json_string = "[[ ]] "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :unclosed_array, 16}
      assert :binary.part(json_string, 16, 1) == " "
    end

    test "multiple array values is wrong [ [ true ] , [, ] " do
      json_string = "[ [ true ] , [, ] "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :leading_comma, 14}
      assert :binary.part(json_string, 14, 1) == ","
    end

    test "multiple array values is wrong [] []" do
      json_string = "[] []"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 3}

      assert :binary.part(json_string, 3, 1) == "["
    end

    test "leading 0 integer" do
      json_string = "[001]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :leading_zero, 1}

      assert :binary.part(json_string, 1, 1) == "0"
    end

    test "leading 0 negative integer" do
      json_string = "[-001]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :leading_zero, 2}

      assert :binary.part(json_string, 2, 1) == "0"
    end

    test "0 is okay?" do
      json_string = "[0]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["0"]
    end

    test "minus 0 is unhinged but fine I guess? What even are numbers" do
      json_string = "[-0]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["-0"]
    end

    test "minus 0 exp is unhinged but fine I guess? What even are numbers" do
      json_string = "[-0e+1]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["-0e+1"]
    end

    test "too many closing arrays" do
      json_string = "[  true ]  ]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 11}

      assert :binary.part(json_string, 11, 1) == "]"
    end

    test "unopened array example" do
      json_string = "[ [], ] ]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :trailing_comma, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end

    test "unopened array is really just an errant comma" do
      json_string = "[  true ],  ]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 9}

      assert :binary.part(json_string, 9, 1) == ","
    end

    test "start with a closing array." do
      json_string = " ]  ["
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == "]"
    end

    test "valid array but then weird chars" do
      json_string = " [  ] : "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 6}

      assert :binary.part(json_string, 6, 1) == ":"
    end

    test "empty string array error" do
      json_string = "[\"\""
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :unclosed_array, 2}
    end

    test "empty string array" do
      json_string = "[\"\", \"\",\"\",\"\"]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["", "", "", ""]
    end

    test " unescaped tab " do
      fp = "./test/test_parsing/n_string_unescaped_tab.json"
      json_string = File.read!(fp)
      acc = []
      # Apparently this is meant to error?
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == ["\t"]
    end

    test "./test/test_parsing/n_structure_100000_opening_arrays.json" do
      fp = "./test/test_parsing/n_structure_100000_opening_arrays.json"
      json_string = File.read!(fp)
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unclosed_array, 99999}
    end

    test "open array then an erroneous char" do
      json_string = "[ bbb]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_json_character, 2}
    end

    test "closing an array early is an error." do
      json_string = "[ { ] "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_object_key, 4}
    end

    test "closing an array in an object early is an error." do
      json_string = "{ \"a\": ] } "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unopened_array, 7}

      # we point to the char before the closing bracket. BUT should this be an unclosed
      # object OR an unopened array. Probs the latter.
      assert :binary.part(json_string, 7, 1) == "]"
    end

    test "closing an object early is an error." do
      json_string = "{\"b\": { \"a\": [ } } "
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unclosed_array, 14}

      assert :binary.part(json_string, 14, 2) == " }"
    end

    test "not closing an object is an error." do
      # Todo put the number back
      json_string = "[ [ { \"a\": 1] ]"
      acc = []
      # Should this be missing comma? unclosed object really
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unclosed_object, 11}

      assert :binary.part(json_string, 11, 1) == "1"
    end

    test " [{}] " do
      json_string = "[{}]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == [%{}]
    end
  end

  describe "objects" do
    @describetag :objects
    test "a simple object" do
      json_string = "{ \f\n\t\r  \"a\": 1 \f\n\t\r}"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{"a" => "1"}
    end

    test "missing value error" do
      json_string = "[ [ { \"a\": ] ]"
      acc = []
      # Should this be missing comma? unclosed object really
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unopened_array, 11}

      assert :binary.part(json_string, 11, 1) == "]"
    end

    test "missing val with comma" do
      json_string = "[ [ { \"a\": ,] ]"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :missing_object_value, 10}

      assert :binary.part(json_string, 10, 2) == " ,"
    end

    test "unclosed object and array" do
      json_string = "[ {"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :invalid_object_key, 2}

      assert :binary.part(json_string, 2, 1) == "{"
    end

    test "{ \"thing\": [ }" do
      json_string = "{ \"thing\": [ }"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :unclosed_array, 12}

      assert :binary.part(json_string, 11, 2) == "[ "
    end

    test " {} " do
      json_string = "{  }"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{}
    end

    test " [ {} " do
      json_string = "[ {}"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :unclosed_array, 3}
      assert :binary.part(json_string, 3, 1) == "}"
    end

    test " multiple element objects " do
      json_string = "{ \"a\": 1, \"b\": 2}"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{"a" => "1", "b" => "2"}
    end

    test "duplicate object keys is an error" do
      json_string = "{ \"a\": 1, \"a\": 2}"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{"a" => "2"}
    end

    test " dupes " do
      json_string = """
      {"a":"b","a":"c"}
      """

      acc = []
      # WHILST we can implement the handler to prevent duplicate keys, the spec seems
      # to want ton allow it. See the handler above for how one could prevent/error on
      # them if one so chose: {:error, :duplicate_object_key, "a"}

      # for now, last write wins I guess.
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{"a" => "c"}
    end

    test "empty object keys are allowed" do
      json_string = "{ \"\": 1}"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{"" => "1"}
    end

    test " {\"a\":[]} " do
      json_string = "{\"a\":[]}"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{"a" => []}
    end

    test "nestd objects and arrays" do
      json_string = """
      {"x":[{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}], "id": "yyyyyyyyyyyyyyyyyyyyyyyyy"}
      """

      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == %{
               "id" => "yyyyyyyyyyyyyyyyyyyyyyyyy",
               "x" => [%{"id" => "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}]
             }
    end

    test " object with bare value after  " do
      json_string = """
      {"a": true} "x"
      """

      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 12}

      assert :binary.part(json_string, 12, 3) == "\"x\""
    end
  end

  # describe "hexadigits ?" do
  # end

  describe "yes cases" do
    for "y_" <> _ = f <- File.ls!("./test/test_parsing/") do
      test "#{"./test/test_parsing/" <> f}" do
        fp = "./test/test_parsing/" <> unquote(f)
        json_string = File.read!(fp)
        acc = []
        # These just assert that we don't error. Really we should generate the text for
        # each one and go back and write the expected result in each test, so we can assert
        # we are actually creating something good.
        refute match?({:error, _, _}, JxonIndexes.parse(json_string, TestHandler, 0, acc))
      end
    end
  end

  # describe "i for optional" do
  #   for "i_" <> _ = f <- File.ls!("./test/test_parsing/") do
  #     test "#{"./test/test_parsing/" <> f}" do
  #       fp = "./test/test_parsing/" <> unquote(f)
  #       json_string = File.read!(fp)
  #       acc = []

  #       refute match?({:error, _, _}, JxonIndexes.parse(json_string, TestHandler, 0, acc))
  #     end
  #   end
  # end

  # describe "no cases" do
  #   for "n_" <> _ = f <- File.ls!("./test/test_parsing/") do
  #     test "#{"./test/test_parsing/" <> f}" do
  #       fp = "./test/test_parsing/" <> unquote(f)
  #       json_string = File.read!(fp)
  #       acc = []
  #       assert match?({:error, _, _}, JxonIndexes.parse(json_string, TestHandler, 0, acc))
  #     end
  #   end
  # end
end
