defmodule OriginalSlimWithSchemaTest do
  use ExUnit.Case

  @acc {Schema, []}

  describe "bare values" do
    @describetag :values
    test "an invalid bare value whitespace" do
      json_string = "    banana  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == "b"
    end

    test "just space is an error..." do
      json_string = " "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               []
    end

    test "an invalid bare value" do
      json_string = "banana"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 0}

      assert :binary.part(json_string, 0, 1) == "b"
    end

    test "an invalid bare value after a valid one" do
      json_string = "true banana"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 5}

      assert :binary.part(json_string, 5, 1) == "b"
    end

    test "bare values surrounded by white space works" do
      json_string = " \t \n \r false  \t \n \r  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 true
               ]

      json_string = "  \t \n \r  true  \t \n \r  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 true
               ]

      json_string = "  \t \n \r  null  \t \n \r  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 nil
               ]
    end

    test "invalid multiple bare values with whitespace" do
      json_string = "    false  true  "
      # What is a good error message here? Pointing to the part that went wrong is probably
      # good, but might be hard for large strings?

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 11}

      assert :binary.part(json_string, 11, 1) == "t"

      json_string = "  \t \n \r  true  \t \n \r  false   \t \n \r   "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 22}

      assert :binary.part(json_string, 22, 1) == "f"

      json_string = "  \t \n \r  null  \t \n \r  true   \t \n \r  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 22}

      assert :binary.part(json_string, 22, 1) == "t"
    end

    test "invalid multiple bare values with whitespace and nested errors" do
      json_string = "  \t \n \r  false   \t \n \r   tru   \t \n \r   "
      # What is a good error message here? Pointing to the part that went wrong is probably
      # good, but might be hard for large strings?

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 25}

      assert :binary.part(json_string, 25, 1) == "t"
    end

    test "multiple bare values starting with true" do
      json_string = "   \t \n \r     true    \t \n \r   flse    \t \n \r  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 29}

      assert :binary.part(json_string, 29, 1) == "f"

      json_string = "  \t \n \r      null    \t \n \r    rue  \t \n \r  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 30}

      assert :binary.part(json_string, 30, 1) == "r"
    end

    test "decimal followed by exp is an error" do
      json_string = "1.e"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_decimal_number, 2}
    end

    test "invalid multiple bare values and nested errors" do
      json_string = "false tru"
      # What is a good error message here? Pointing to the part that went wrong is probably
      # good, but might be hard for large strings?

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 6}

      assert :binary.part(json_string, 6, 1) == "t"

      json_string = "true:flse"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ":"

      json_string = "null,rue"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end

    test "invalid multiple bare values" do
      json_string = "false true"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 6}

      assert :binary.part(json_string, 6, 1) == "t"

      json_string = "true:false"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ":"

      json_string = "null,true"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end
  end

  describe "negative numbers" do
    @describetag :neg_ints

    test "leading decimal point" do
      json_string = ".1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 0}
    end

    test "invalid decimal point" do
      json_string = "-..1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 1}
    end

    test "leading decimal point in array is an error" do
      json_string = "[.1]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 1}
    end

    test "invalid decimal point in array" do
      json_string = "[-..1]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 2}
    end

    test "parsing negative numbers is good and fine" do
      json_string = "-1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "-1"
               ]

      json_string = "-10920394059687"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "-10920394059687"
               ]
    end

    test "negative with whitespace is wrong" do
      json_string = "- 1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == " "
    end

    test "negative sign only is wrong" do
      json_string = "-"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 0}

      assert :binary.part(json_string, 0, 1) == "-"
    end

    test "int with error chars after" do
      json_string = "-1;"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 2}

      assert :binary.part(json_string, 2, 1) == ";"
    end

    test "int with exponent" do
      json_string = "-1e40  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "-1e40"}
               ]
    end

    test " 2.e3 is an error" do
      json_string = "2.e3  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_decimal_number, 2}

      assert :binary.part(json_string, 2, 1) == "e"
    end

    test " 2. is an error" do
      json_string = "2.    "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_decimal_number, 2}

      assert :binary.part(json_string, 2, 1) == " "
    end

    test " 2.+ is an error" do
      json_string = "2.+    "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_decimal_number, 2}

      assert :binary.part(json_string, 2, 1) == "+"
    end

    test "+ve int with exponent" do
      json_string = "1e40  "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "1e40"
               ]
    end

    test "int with capital exponent" do
      json_string = "-1E40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "-1E40"}
               ]
    end

    test "int with positive exponent" do
      json_string = "-11e+2"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "-11e+2"
               ]

      json_string = "-11E+2"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "-11E+2"
               ]
    end

    test "double e is wrong" do
      json_string = "-11eE+2"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 4}

      assert :binary.part(json_string, 4, 1) == "E"

      json_string = "-11Ee+2"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 4}

      assert :binary.part(json_string, 4, 1) == "e"
    end

    test "letter is wrong" do
      json_string = "-11eEa2"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 4}
    end

    test "negative decimal" do
      json_string = "-1.5"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 float: "-1.5"
               ]
    end

    test "leading 0s are not allowed negative decimal" do
      json_string = "-01.5"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_zero, 1}

      assert :binary.part(json_string, 1, 1) == "0"
    end

    test "leading 0s are not allowed -ve int" do
      json_string = "-0001"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_zero, 1}

      assert :binary.part(json_string, 1, 1) == "0"
    end

    test "white space for a bare value is no invalid" do
      json_string = "-1.5   \n \t \r"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:float, "-1.5"}
               ]
    end

    test "invalid int" do
      json_string = "-1.5;"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}
    end

    test "multiple bare values is wrong -ve ints" do
      json_string = "-1 -2 3 4 5"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 3}

      assert :binary.part(json_string, 3, 1) == "-"
    end

    test "multiple bare values is wrong -ve ints invalid char" do
      json_string = "-1.2 b -2.3 \n\t\r"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 5}

      assert :binary.part(json_string, 5, 1) == "b"
    end

    test "multiple bare values is wrong -ve ints whitespace" do
      json_string = "-1.2\n-2.3 \n\t\r"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 5}

      assert :binary.part(json_string, 5, 1) == "-"
    end
  end

  describe "positive numbers" do
    @describetag :pos_ints
    test "numbers with 0s in" do
      json_string = "102030405060708099887654321"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "102030405060708099887654321"
               ]
    end

    test "we can parse a number" do
      json_string = "1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "1"
               ]
    end

    test "we can parse a float" do
      json_string = "1.500"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 float: "1.500"
               ]
    end

    test "errors for +ve integer" do
      json_string = "1;"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == ";"
    end

    test "0 is allowed" do
      json_string = "0"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "0"}
               ]
    end

    test "0exp is allowed" do
      json_string = "0e1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "0e1"
               ]
    end

    test "0exp + is allowed" do
      json_string = "0e+1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "0e+1"}
               ]
    end

    test "0exp - is allowed" do
      json_string = "0e-1"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "0e-1"
               ]
    end

    test "0exp error is allowed" do
      json_string = "0e"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 2}
    end

    test "-0 is allowed" do
      json_string = "-0"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 integer: "-0"
               ]
    end

    test "errors for +ve float" do
      json_string = "1.5;"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 3}

      assert :binary.part(json_string, 3, 1) == ";"
    end

    test "exponents" do
      json_string = "1.5e+40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 float: "1.5e+40"
               ]

      json_string = "1.5e-40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:float, "1.5e-40"}
               ]

      json_string = "1.5E+40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:float, "1.5E+40"}
               ]

      json_string = "1.5E-40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 # Wait is this a float or an int. I guess a positive one would be an integer
                 # actually?
                 {:float, "1.5E-40"}
               ]

      json_string = "15e+40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "15e+40"}
               ]

      json_string = "15e-40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 # Is this actually a float. Maybe having :numbers and :exponents or something..
                 {:integer, "15e-40"}
               ]

      json_string = "15E+40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "15E+40"}
               ]

      json_string = "15E-40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:integer, "15E-40"}
               ]

      json_string = "15ee+40"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 3}

      assert :binary.part(json_string, 3, 1) == "e"
    end

    test "exponent error no number after e" do
      json_string = "15e"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 3}
    end

    test "exponent error no number after E" do
      json_string = "15E"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_exponent, 3}
    end

    test "leading 0s" do
      json_string = "001"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_zero, 0}

      json_string = "01.5"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_zero, 0}

      assert :binary.part(json_string, 0, 1) == "0"
    end

    test "multiple bare values is wrong" do
      json_string = "1 2 3 4 5"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 2}

      assert :binary.part(json_string, 2, 1) == "2"
    end

    test "multiple with a decimal number" do
      json_string = "1.2 . 2.3 \n\t\r"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 4}

      assert :binary.part(json_string, 4, 1) == "."
    end

    test "multiple decimals" do
      json_string = "1.2\n2.3 \n\t\r"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
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

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "[1, 2, 3, 4]"
               ]
    end

    test "escaped quotation mark in string" do
      json_string = File.read!("/Users/Adz/Projects/jxon/test/fixtures/escapes_string.json")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "this is what he said: \\\"no\\\""
               ]
    end

    test "single backslash is not an error because we are just passing through the raw string as is" do
      json_string = ~s("\\ ")
      # This would be an error you would handle and implement in the callback where you did
      # string escaping.
      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "\\ "
               ]
    end

    test "When the string is not terminated we error" do
      json_string = ~s("\\")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unterminated_string, 2}

      assert :binary.part(json_string, 2, 1) == "\""
    end

    test ~s("\\"\\\\\\/\\b\\f\\n\\r\\t") do
      json_string = ~s("\\"\\\\\\/\\b\\f\\n\\r\\t")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "\\\"\\\\\\/\\b\\f\\n\\r\\t"
               ]
    end

    test "unicode escapes don't actually escape, they just return as is" do
      # This enables JCS
      json_string = ~s("\\u2603")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "\\u2603"
               ]

      json_string = ~s("\\u2028\\u2029")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "\\u2028\\u2029"
               ]

      json_string = ~s("\\uD834\\uDD1E")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "\\uD834\\uDD1E"
               ]

      json_string = ~s("\\uD834\\uDD1E")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:string, "\\uD834\\uDD1E"}
               ]

      json_string = ~s("\\uD799\\uD799")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:string, "\\uD799\\uD799"}
               ]

      json_string = ~s("✔︎")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 {:string, "✔︎"}
               ]
    end

    test "multiple strings when there shouldn't be" do
      json_string = ~s("this is valid " "this is not!")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 17}

      assert :binary.part(json_string, 17, 1) == "\""
    end

    test "a string with numbers in it works" do
      json_string = ~s(" one 1 two 2 ")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: " one 1 two 2 "
               ]
    end

    test "numbers in a string all having fun" do
      json_string = ~s("1,2,3,4,5,6")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 string: "1,2,3,4,5,6"
               ]
    end
  end

  describe "arrays" do
    @describetag :arrays

    test " [\"a\"] " do
      json_string = File.read!("./test/test_parsing/y_structure_trailing_newline.json")

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:string, "a"},
                 :array_end
               ]
    end

    test "open array whitespace and an error is an error" do
      json_string = "[ b "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 2}

      assert :binary.part(json_string, 2, 1) == "b"
    end

    test "open array and an error is an error" do
      json_string = "[b "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == "b"
    end

    test "empty array" do
      json_string = "[]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :array_end
               ]
    end

    test "array of one number" do
      json_string = "[1]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:integer, "1"},
                 :array_end
               ]
    end

    test "array of one number trialing comma" do
      json_string = "[1,]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :trailing_comma, 2}
    end

    test "array of string" do
      json_string = "[\"1\"]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:string, "1"},
                 :array_end
               ]
    end

    test "array of boolean and nil" do
      json_string = "[true, false, null]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 true,
                 false,
                 nil,
                 :array_end
               ]
    end

    test "nested stuff" do
      json_string = "[[true, []], [[\"a\",false,\"b\"\n\t\r], [1, null, 2.50, 112.2, 8]]]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :array_start,
                 true,
                 :array_start,
                 :array_end,
                 :array_end,
                 :array_start,
                 :array_start,
                 {:string, "a"},
                 false,
                 {:string, "b"},
                 :array_end,
                 :array_start,
                 {:integer, "1"},
                 nil,
                 {:float, "2.50"},
                 {:float, "112.2"},
                 {:integer, "8"},
                 :array_end,
                 :array_end,
                 :array_end
               ]
    end

    # Error cases as I think of them.
    test "unclosed array" do
      json_string = "[1"

      assert {:error, :unclosed_array, index} =
               JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc)

      assert index == 1
      assert :binary.part(json_string, index, 1) == "1"
    end

    test "multiple non comma'd elements" do
      json_string = "[1 2]"

      assert {:error, :multiple_bare_values, index} =
               JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc)

      assert index == 3
      assert :binary.part(json_string, index, 1) == "2"
    end

    test "unclosed multiple non comma'd elements" do
      json_string = "[1 2"

      assert {:error, :multiple_bare_values, index} =
               JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc)

      assert index == 3
      assert :binary.part(json_string, index, 1) == "2"
    end

    test "just commas" do
      json_string = "[,]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_comma, 1}

      assert :binary.part(json_string, 1, 1) == ","
    end

    test "double comma" do
      json_string = "[1,,,,,,]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :double_comma, 3}

      assert :binary.part(json_string, 3, 1) == ","
    end

    test "leading_comma comma" do
      json_string = "[,,,,,,]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_comma, 1}

      assert :binary.part(json_string, 1, 1) == ","
    end

    test "unclosed trailing comma" do
      json_string = "[1,2  , "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 7}

      assert :binary.part(json_string, 7, 1) == " "
    end

    test "trailing comma [1,2,] " do
      json_string = "[1,2,]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :trailing_comma, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end

    # NESTING
    test "nested array" do
      json_string = "[[]]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :array_start,
                 :array_end,
                 :array_end
               ]
    end

    test "unclosed" do
      json_string = "[ {\"q\" : ["

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 9}

      assert :binary.part(json_string, 9, 1) == "["
    end

    test "unclosed 2" do
      json_string = "{\"q\" : {"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_object_key, 7}

      assert :binary.part(json_string, 7, 1) == "{"
    end

    test "nested unclosed array" do
      json_string = "[[]"
      # It would be great to point to the array that is unclosed. How to do that? Well we
      # would have to leverage the stack to store the index of each currently open array.
      # We have to store each because we can have nested arrays and so as we close the inner
      # one we want the "unclosed" one to be the now pointed at char. Once we have a working
      # version we can benchmark and decide if it's worth it.

      # We could also be like, technically the first unclosed array will always be unclosed.
      # If there are more unclosed arrays inside it then that's good and all but still the
      # outer one is unclosed. But is that a help to someone?
      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 2}

      assert :binary.part(json_string, 2, 1) == "]"
    end

    test "nested unclosed array whitespace" do
      json_string = "[[  ] "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 4}

      assert :binary.part(json_string, 4, 1) == "]"
    end

    test "multiple nested array" do
      json_string = "[[], [1, [3]]]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :array_start,
                 :array_end,
                 :array_start,
                 {:integer, "1"},
                 :array_start,
                 {:integer, "3"},
                 :array_end,
                 :array_end,
                 :array_end
               ]
    end

    test "nested with whitespace" do
      json_string = "[ [  \n\t ]\n\t\r,[  ] ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :array_start,
                 :array_end,
                 :array_start,
                 :array_end,
                 :array_end
               ]
    end

    test "unclosed array in an object" do
      # json_string = "{ \"A\": [ ], \"B\": [ [ true ], \"thing\": [] }"
      # json_string = "{ "A": [ ], "B": [ [ true ] }"
      # json_string = "{ "A": [ ], "B": [ [ true ] , }"
      # json_string = "[ [ true ] , [,  "
      json_string = "[ [ true ] , [ ] "
      # json_string = "[ [ [ true ] ], [ ] "
      # json_string = "[[ ]] "
      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 15}

      assert :binary.part(json_string, 15, 1) == "]"
    end

    test "multiple array values is wrong [ [ true ] , [, ] " do
      json_string = "[ [ true ] , [, ] "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_comma, 14}

      assert :binary.part(json_string, 14, 1) == ","
    end

    test "multiple array values is wrong [] []" do
      json_string = "[] []"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 3}

      assert :binary.part(json_string, 3, 1) == "["
    end

    test "leading 0 integer" do
      json_string = "[001]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_zero, 1}

      assert :binary.part(json_string, 1, 1) == "0"
    end

    test "leading 0 negative integer" do
      json_string = "[-001]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :leading_zero, 2}

      assert :binary.part(json_string, 2, 1) == "0"
    end

    test "0 is okay?" do
      json_string = "[0]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:integer, "0"},
                 :array_end
               ]
    end

    test "minus 0 is unhinged but fine I guess? What even are numbers" do
      json_string = "[-0]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:integer, "-0"},
                 :array_end
               ]
    end

    test "minus 0 exp is unhinged but fine I guess? What even are numbers" do
      json_string = "[-0e+1]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:integer, "-0e+1"},
                 :array_end
               ]
    end

    test "too many closing arrays" do
      json_string = "[  true ]  ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 11}

      assert :binary.part(json_string, 11, 1) == "]"
    end

    test " [0e+1] " do
      json_string = "[0e+1]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:integer, "0e+1"},
                 :array_end
               ]
    end

    test "unopened array example" do
      json_string = "[ [], ] ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :trailing_comma, 4}

      assert :binary.part(json_string, 4, 1) == ","
    end

    test "unopened array is really just an errant comma" do
      json_string = "[  true ],  ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 9}

      assert :binary.part(json_string, 9, 1) == ","
    end

    test "start with a closing array." do
      json_string = " ]  ["

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 1}

      assert :binary.part(json_string, 1, 1) == "]"
    end

    test "valid array but then weird chars" do
      json_string = " [  ] : "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 6}

      assert :binary.part(json_string, 6, 1) == ":"
    end

    test "empty string array error" do
      json_string = "[\"\""

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 2}
    end

    test "empty string array" do
      json_string = "[\"\", \"\",\"\",\"\"]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:string, ""},
                 {:string, ""},
                 {:string, ""},
                 {:string, ""},
                 :array_end
               ]
    end

    test " unescaped tab " do
      fp = "./test/test_parsing/n_string_unescaped_tab.json"
      json_string = File.read!(fp)
      # Apparently this is meant to error?
      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 {:string, "\t"},
                 :array_end
               ]
    end

    # test "./test/test_parsing/n_structure_100000_opening_arrays.json" do
    #   fp = "./test/test_parsing/n_structure_100000_opening_arrays.json"
    #   json_string = File.read!(fp)

    #   assert JxonSlimOriginal.parse(json_string,json_string, OriginalSlimWithSchema, 0, @acc) ==
    #            {:error, :unclosed_array, 99999}
    # end

    test "open array then an erroneous char" do
      json_string = "[ bbb]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_json_character, 2}
    end

    test "closing an array early is an error." do
      json_string = "[ { ] "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_object_key, 4}
    end

    test "closing an array in an object early is an error." do
      json_string = "{ \"a\": ] } "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unopened_array, 7}

      # we point to the char before the closing bracket. BUT should this be an unclosed
      # object OR an unopened array. Probs the latter.
      assert :binary.part(json_string, 7, 1) == "]"
    end

    test "closing an object early is an error." do
      json_string = "{\"b\": { \"a\": [ } } "

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 14}

      assert :binary.part(json_string, 14, 2) == " }"
    end

    test "not closing an object is an error." do
      json_string = "[ [ { \"a\": 1] ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_object, 11}

      assert :binary.part(json_string, 11, 1) == "1"
    end

    test " [{}] " do
      json_string = "[{}]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :object_start,
                 :object_end,
                 :array_end
               ]
    end

    test " [{} ] " do
      json_string = "[{} ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :object_start,
                 :object_end,
                 :array_end
               ]
    end
  end

  describe "objects" do
    @describetag :objects
    test "a simple object" do
      json_string = "{ \f\n\t\r  \"a\": 1 \f\n\t\r}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 {:integer, "1"},
                 :object_end
               ]
    end

    test "missing value error" do
      json_string = "[ [ { \"a\": ] ]"
      # Should this be missing comma? unclosed object really
      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unopened_array, 11}

      assert :binary.part(json_string, 11, 1) == "]"
    end

    test "missing val with comma" do
      json_string = "[ [ { \"a\": ,] ]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :missing_object_value, 10}

      assert :binary.part(json_string, 10, 2) == " ,"
    end

    test "unclosed object and array" do
      json_string = "[ {"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :invalid_object_key, 2}

      assert :binary.part(json_string, 2, 1) == "{"
    end

    test "{ \"thing\": [ }" do
      json_string = "{ \"thing\": [ }"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 12}

      assert :binary.part(json_string, 11, 2) == "[ "
    end

    test " {} " do
      json_string = "{  }"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 :object_end
               ]
    end

    test "error case" do
      json_string = "{ \"a\": ] }"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unopened_array, 7}
    end

    test "object with an object" do
      json_string = "{ \"a\": [{ \"b\": 2}], \"c\": 3 }"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 :array_start,
                 :object_start,
                 {:object_key, "b"},
                 {:integer, "2"},
                 :object_end,
                 :array_end,
                 {:object_key, "c"},
                 {:integer, "3"},
                 :object_end
               ]
    end

    test "object with an array of object" do
      json_string = "{ \"a\": [{ \"b\": \"2\"}] }"
      # ["a", :all, "b"]
      # ["a", :all, "c"]

      # ["a", :all, ["c", "b"]]

      # Are the paths here more linear than XML?
      # You can have a list which would repeat.

      # Some key points are: You have to be able to know when you are done with the items
      # being checked for. For objects that's usually easy because there cannot be duplicate
      # keys, but for lists there are wrinkles.

      # We basically need to be able to know when we are done with the object so that
      # we can throw it away or like pop it off the stack.

      # Basically can the tree of paths be represented as a stack? Yes quite easily if
      # we can guarantee the order of the nodes. But unfortunately we can't really do that.

      # We could build a stack an assume any order, but then in order to search that we
      # would have to know how many items to skip in order to skip over all the children.
      # Which doesn't seem impossible because we can store extra integers that store that.
      # I think this would only actually be good if we had an array and could do pointer math?
      # We'd effectively be building a linked list of sorts? And we'd have to implement
      # the search in it ourselves.
      # I think the primitives would be like "nest level" or something. Then it would be
      # like "search for key" which would have to know how many children to skip...
      # I guess really it would just be where the next element that is its sibling is. And
      # that one would point to its sibling. It's a jump really, a go to.

      # lists can be of different types, so being able to say which element in the list you
      # expect to see where is trickier than it sounds.
      # we can ignore that for now though.

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 :array_start,
                 :object_start,
                 {:object_key, "b"},
                 {:string, "2"},
                 :object_end,
                 :array_end,
                 :object_end
               ]
    end

    test " [ {} " do
      json_string = "[ {}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 3}

      assert :binary.part(json_string, 3, 1) == "}"
    end

    test " multiple element objects " do
      json_string = "{ \"a\": 1, \"b\": 2}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 {:integer, "1"},
                 {:object_key, "b"},
                 {:integer, "2"},
                 :object_end
               ]
    end

    test "duplicate object keys is an error" do
      json_string = "{ \"a\": 1, \"a\": 2}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 {:integer, "1"},
                 {:object_key, "a"},
                 {:integer, "2"},
                 :object_end
               ]
    end

    test " dupes " do
      json_string = """
      {"a":"b","a":"c"}
      """

      # WHILST we can implement the handler to prevent duplicate keys, the spec seems
      # to want ton allow it. See the handler above for how one could prevent/error on
      # them if one so chose: {:error, :duplicate_object_key, "a"}

      # for now, last write wins I guess.
      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 {:string, "b"},
                 {:object_key, "a"},
                 {:string, "c"},
                 :object_end
               ]
    end

    test "empty object keys are allowed" do
      json_string = "{ \"\": 1}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, ""},
                 {:integer, "1"},
                 :object_end
               ]
    end

    test "[}" do
      json_string = "[}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :unclosed_array, 0}
    end

    test " {\"a\":[]} " do
      json_string = "{\"a\":[]}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "a"},
                 :array_start,
                 :array_end,
                 :object_end
               ]
    end

    test "nestd objects and arrays" do
      json_string = """
      {"x":[{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}], "id": "yyyyyyyyyyyyyyyyyyyyyyyyy"}
      """

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "x"},
                 :array_start,
                 :object_start,
                 {:object_key, "id"},
                 {:string, "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"},
                 :object_end,
                 :array_end,
                 {:object_key, "id"},
                 {:string, "yyyyyyyyyyyyyyyyyyyyyyyyy"},
                 :object_end
               ]
    end

    test " object with bare value after  " do
      json_string = """
      {"a": true} "x"
      """

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               {:error, :multiple_bare_values, 12}

      assert :binary.part(json_string, 12, 3) == "\"x\""
    end

    test "object pointing to an object" do
      json_string = "{\"files\": {}}"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :object_start,
                 {:object_key, "files"},
                 :object_start,
                 :object_end,
                 :object_end
               ]
    end

    test "lists of objects [{}, {}, {}, {}]" do
      json_string = "[{}, {}, {}, {}]"

      assert JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc) ==
               [
                 :array_start,
                 :object_start,
                 :object_end,
                 :object_start,
                 :object_end,
                 :object_start,
                 :object_end,
                 :object_start,
                 :object_end,
                 :array_end
               ]
    end
  end

  describe "yes cases" do
    for "y_" <> _ = f <- File.ls!("./test/test_parsing/") do
      test "#{"./test/test_parsing/" <> f}" do
        fp = "./test/test_parsing/" <> unquote(f)
        json_string = File.read!(fp)
        # These just assert that we don't error. Really we should generate the text for
        # each one and go back and write the expected result in each test, so we can assert
        # we are actually creating something good.
        refute match?(
                 {:error, _, _},
                 JxonSlimOriginal.parse(json_string, json_string, OriginalSlimWithSchema, 0, @acc)
               )
      end
    end
  end
end
