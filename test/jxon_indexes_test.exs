defmodule JxonIndexesTest do
  use ExUnit.Case

  defmodule TestHandler do
    @moduledoc """
    TODO eventually experiment with generating a flat list (:array) of values in the source
    and see if it's efficient to whip through the list to extract values. Need to think about
    how to flatten nested data but I kind of think you just add a 3rd dimension which is like
    jump - how many lines to jump to get to the Nth element.... Would love to play with this.
    """

    def do_true(original_binary, start_index, end_index, acc) do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_false(original_binary, start_index, end_index, acc) do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_null(original_binary, start_index, end_index, acc) do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_string(original_binary, start_index, end_index, acc) do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_negative_number(original_binary, start_index, end_index, acc) do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def do_positive_number(original_binary, start_index, end_index, acc) do
      # we add 1 because the indexes are 0 indexed but length isn't.
      len = end_index - start_index + 1
      value = :binary.part(original_binary, start_index, len)
      update_acc(value, acc)
    end

    def start_of_array(original_binary, start_index, acc) do
      if :binary.part(original_binary, start_index, 1) != "[" do
        raise "Array index error"
      end

      [[] | acc]
    end

    def end_of_array(original_binary, end_index, [array, parent | rest])
        when is_list(array) and is_list(parent) do
      if :binary.part(original_binary, end_index, 1) != "]" do
        raise "Array index error"
      end

      # when do we collapse into the thing below? Always?
      [[Enum.reverse(array) | parent] | rest]
    end

    def end_of_array(_original_binary, _end_index, [array | rest]) do
      [Enum.reverse(array) | rest]
    end

    def end_of_document(original_binary, end_index, [acc]) do
      # This should not be out of range. It shouldn't be short either we could assert on that.
      :binary.part(original_binary, end_index, 1)
      acc
    end

    defp update_acc(value, [list | rest]) when is_list(list) do
      [[value | list] | rest]
    end

    defp update_acc(value, acc) do
      [value | acc]
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
               {:error, :multiple_bare_values, 4}

      assert :binary.part(json_string, 4, 1) == ":"

      json_string = "null,rue"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 4}

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
               {:error, :multiple_bare_values, 4}

      assert :binary.part(json_string, 4, 1) == ":"

      json_string = "null,true"
      acc = []

      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) ==
               {:error, :multiple_bare_values, 4}

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
               {:error, :multiple_bare_values, 4}

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

    # Error cases as I think of them.
    test "unclosed array" do
      json_string = "[1"
      acc = []

      assert {:error, :missing_comma, index} = JxonIndexes.parse(json_string, TestHandler, 0, acc)

      assert index == 0
      assert :binary.part(json_string, index, 1) == "["
    end

    test "multiple non comma'd elements" do
      json_string = "[1 2]"
      acc = []

      assert {:error, :missing_comma, index} = JxonIndexes.parse(json_string, TestHandler, 0, acc)

      assert index == 2
      assert :binary.part(json_string, index, 1) == " "
    end

    test "unclosed multiple non comma'd elements" do
      json_string = "[1 2"
      acc = []
      assert {:error, :missing_comma, index} = JxonIndexes.parse(json_string, TestHandler, 0, acc)
      assert index == 2
      assert :binary.part(json_string, index, 1) == " "
    end

    test "just commas" do
      json_string = "[,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :trailing_comma, 1}
      assert :binary.part(json_string, 1, 1) == ","
    end

    test "double comma" do
      json_string = "[,,,,,,]"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :double_comma, 2}
      assert :binary.part(json_string, 2, 1) == ","
    end

    test "unclosed trailing comma" do
      json_string = "[1,2  , "
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :unclosed_array, 7}
      assert :binary.part(json_string, 7, 1) == " "
    end

    test "trailing comma" do
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
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :missing_comma, 2}
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
      json_string = "[ [ true ] , []"
      acc = []
      assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == {:error, :missing_comma, 14}
      assert :binary.part(json_string, 14, 1) == "]"
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

    # test "start with a closing array." do
    #   json_string = " ]  ["
    #   acc = []
    #   assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "[1]"
    # end

    # test "valid array but then weird chars" do
    #   json_string = " [  ] : "
    #   json_string = " [  ]  } "
    #   This one is valid.
    #   json_string = " [  ]"

    #   acc = []
    #   assert JxonIndexes.parse(json_string, TestHandler, 0, acc) == "[1]"
    # end
  end

  # for f <- File.ls!("/Users/Adz/Projects/jxon/test/test_parsing/") |> Enum.take(1) do
  #   test "#{"/Users/Adz/Projects/jxon/test/test_parsing/" <> f}" do
  #     fp = "/Users/Adz/Projects/jxon/test/test_parsing/" <> unquote(f)
  #     json_string = File.read!(fp) |> IO.inspect(limit: :infinity, label: "ss")
  #     acc = []
  #     assert JxonIndexes.parse(json_string, TestHandler, 0,acc) == 1
  #   end
  # end
end
