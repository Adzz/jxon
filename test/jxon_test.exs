# defmodule JxonTest do
#   use ExUnit.Case

#   @moduledoc """

#   # 3 parts
#   # 1. Create the DOM (feed in schemas)
#   # 2. Extract data from the DOM (data accessor)
#   # 3. Cast said data.

#   # JSONpath data accessor should be possible (maybe). Whether it's good or not... not sure/
#   # has a use when you don't know or care what the data looks like. I'm not sure when that
#   # is though, especially if you have the correct feedback loop. Because knowing specific
#   # paths to things is good, aggregating them is another issue.

#   # JSONpath accessor though is tricky to "expand". It's tricky to understand the specific
#   # things that the path wants, making it hard to use it to slim down the DOM.

#   # Also JSONpath suffers from the same problems that xpath does. First, if you get a wrong
#   # result you don't know where in the path things went amiss. You just get nil. Take this:
#       $..phoneNumbers[1].type

#   We get no result, is it because the data looks like this:
#   {
#     "phoneNumbers": [
#       {"type": "iPhone", "number": "0123-4567-8888"},
#       {"number": "0123-4567-8910"}
#     ]
#   }

#   Or like this:

#   {
#     "phoneNumbers": [
#       {"type": "iPhone", "number": "0123-4567-8888"}
#     ]
#   }

#   So although the syntax is compact... it just helps in the short term, with the least
#   problematic part of querying data. It's basically a json regex.

#   There probably is a case where you want some nested value and you don't care what key(s)
#   the key you are after lives under. PROBABLY means "I can in theory imagine it" but in truth
#   most of the time it really will matter. Either you know the shape of your data, in which
#   case enumerating the paths down to the part you want is not hard, or you do not know it
#   and in which case how do you know what you are querying is correct? It's better to form
#   hypothesis and have the tooling confirm or deny them. So enumerate each path you want, then
#   later possibly at some different level of abstraction aggregate them.

#   So the point is it seems good until you have to do anything with it. The same as with xpath.

#   In short, instead of JSONpath we could look at what we actually want to do and just allow
#   that.

#    - specify the value of a thing
#    - return a list of stuff
#    - map over a list of stuff?

#   If you introduce an xpath library or a jsonpath library that extracts values from json for you
#   you lose a layer of debugability because you can't easily get in there and figure out whats
#   happening. Whereas if you do the search/extract in elixir you can IO.inspect your life away
#   you can add telemetry trivially. You can do all sorts because you know own that.

#   """

#   defmodule TestHandler do
#     @moduledoc """
#     Not sure what events to use. Json is pretty limited in the data types it represents
#     so it probably makes sense to do the casting. The point of the event handler approach
#     is: 1. Pause / Resume. 2. Stream parse (parse as you go). 3. Skip sections we don't care about

#     What are sections? Well in JSON it can be list items? Object paths. We could get into
#     skipping Nth elements etc but we probably shouldn't...

#     BUT. Point being.. do we let the handlers do the parsing?
#     If we do data schema things then maybe? But the difference is that XML can be full of
#     any arbitrary data type. But in JSON the int is an int is a flot is a binary etc.
#     The most you can do is like aggregate it into something else.

#     So perhaps the events we want are like start/end object, array. Emit string, float,
#     int,

#     I suppose turning floats into Decimal or not is an option. We'd have to parse it enough
#     to detect what it is I think.

#     Is it up to the handler to decide incomplete or not? I suppose we can emit errors
#     if we know it's like an invalid float etc, then let the handler do what it wants with
#     that but we can only do that when we know for sure it is an error. AND we can only
#     emit an event when we have the result. So streaming actually gets a little complicated
#     because if you have a large binary that could be over many bytes and parsing could stop
#     part way through that.... So after each character we need to form an answer of what
#     callback we are querying. Which means we need incomplete for each data type. Who
#     determines where there are more bytes to parse? Because if we have incomplete but the
#     stream is over... then we can error.

#     Jaxon seem to use these events:

#     :start_object
#     :end_object
#     :start_array
#     :end_array
#     {:string, binary}
#     {:integer, integer}
#     {:decimal, float}
#     {:boolean, boolean}
#     nil
#     {:incomplete, binary}
#     {:error, binary}
#     :colon
#     :comma

#     ### Events First Stab

#     How much responsibility do we give to the handlers to validate whether we have valid
#     JSON. Feels like we should give them none. But is that possible in all cases...
#     I dont think so, take an object value, could be nested so we have to see the handler
#     as something that takes streams of tokens and does something with them really.
#     Then the handler can parse / cast and take account of the schema. But what does the
#     schema do in that case? Well it can flatten, specify the things to keep, but the casting
#     is more like aggregation? And choosing decimal or not for other things I guess.

#     we need to be able to tell that a value is coming, ie that the key => value was legit
#     as far as the lexer is concerned. So having an event for colon might not be the worst.
#     That way the handler can tell "okay the key is legit". If we just see a thing that's
#     like "boolean" we wouldn't know is that the legit value or has a syntax error occurred.

#     If we do that does it make sense to do like:

#     start_object
#       object_key
#         String
#       object_value
#         String (type annotated? So we indicate what type the schema lexer says it is.)
#         I suppose the thing here is you might have a float that you want to turn into a Decimal.
#         Would it matter if it appeared as an int in the JSON? Possibly? So having a handler
#         that specifies the type according to the schema is good... Actually we need to think
#         about the paths in the schema. In the XML version we went some way to validating
#         the path itself (both at compile time AND at runtime) by doing things like checking
#         there weren't many when we expected one... ETC. This could be taken arbitrarily far

#     end_object

#     For { "admin?": true}

#     Path will be something like Access. You could extend it if you wanted more runtime
#     checks but it's not clear what is good to bake into the path and what might be more
#     approps elsewhere. I presume it's a question of to how many things the stuff applies
#     and complexity....

#                           # At this point we can check we got a list.
#                           # quite easy to do with json. But that is done in the accessor
#                           # the parser needs the schema to be a graph. Probably nested maps for now.
#     ["key", "another_key", {:all, "sub_key"}, "final_key"]

#     ["key", "another_key", "different_key"]

#     Contraints
#       - To be able to know when something has been consumed, we pop it off (zipper style)
#         We maybe dont have to do that though, we could maybe just anotate it somehow as seen.
#       - We need to know when we have seen everything in a given level?

#     %{
#       "key" => {
#         "another_key" => %{
#           "different_key" => true,
#           "sub_key" => [],
#         }
#       }
#       "somekey" => [
#         "another_key" => %{"different_key" => true},
#         "another_key" => %{"different_key" => false},
#       ]
#     }

#     # when you parse the JSON you will be going depth first as that is the order in which you
#     # see the characters.

#     [
#       [key],  ---->>> this pops off when we go "in" ie nest a level. When we do that we know
#                       we'll never need it back? It's only inner lists that need to keep elements.

#                     I think the rule is remove it from the list, if the list is then empty
#                     remove that whole thing...
#       [another_key],
#       [different_key, sub_key],
#       [[], true],
#     ]

#     it is in effect a zipper. We want to be able to know when we have

#     start_json
#     start_object
#       Object key (?) (presume we have to parse what the key is...) {:key, :integer, int}
#       # Do you see a key as a key? Or is it just that you get an int / string or whatever
#       # after object start and the handler knows okay this must be a key?
#       # The thing immediately following a key is the value always, or it's an error?

#       # the value could be a nested object which would mean what? I guess we can't fill
#       # out the type until we parse everything inside it. So it would be like a stack
#       # anyway...

#       object value (?) {:value, {:object_start}}
#     end_object
#     start_array
#     end_array
#     # Do we also make a guess as to _what_ is incomplete? Might be good if we can?
#     # Could be complex if it's a key for a
#     # These have to be like their own thing because I think they can exist on themselves and
#     # still be valid JSON. So we have to have a way to say "this is a bare value"....
#     int
#     float
#     null
#     boolean
#     binary
#     incomplete
#     end_json

#     """

#     def do_true(_acc), do: true
#     def do_false(_acc), do: false
#     def do_null(_acc), do: nil
#     def do_string(string, _acc), do: string
#     def do_negative_number(number, _acc), do: "-" <> number
#     def do_positive_number(number, _acc), do: number
#     def end_of_document(acc), do: acc
#   end

#   describe "bare values" do
#     test "bare values surrounded by white space works" do
#       json_string = " \t \n \r false  \t \n \r  "
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == false

#       json_string = "  \t \n \r  true  \t \n \r  "
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == true

#       json_string = "  \t \n \r  null  \t \n \r  "
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == nil
#     end

#     test "invalid multiple bare values with whitespace" do
#       json_string = "    false  true  "
#       # What is a good error message here? Pointing to the part that went wrong is probably
#       # good, but might be hard for large strings?
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "  true  "}

#       json_string = "  \t \n \r  true  \t \n \r  false   \t \n \r   "
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "  \t \n \r  false   \t \n \r   "}

#       json_string = "  \t \n \r  null  \t \n \r  true   \t \n \r  "
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "  \t \n \r  true   \t \n \r  "}
#     end

#     test "invalid multiple bare values with whitespace and nested errors" do
#       json_string = "  \t \n \r  false   \t \n \r   tru   \t \n \r   "
#       # What is a good error message here? Pointing to the part that went wrong is probably
#       # good, but might be hard for large strings?
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "   \t \n \r   tru   \t \n \r   "}

#       json_string = "   \t \n \r     true    \t \n \r   flse    \t \n \r  "
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "    \t \n \r   flse    \t \n \r  "}

#       json_string = "  \t \n \r      null    \t \n \r    rue  \t \n \r  "
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "    \t \n \r    rue  \t \n \r  "}
#     end

#     test "invalid multiple bare values and nested errors" do
#       json_string = "false tru"
#       # What is a good error message here? Pointing to the part that went wrong is probably
#       # good, but might be hard for large strings?
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :multiple_bare_values, " tru"}

#       json_string = "true:flse"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :multiple_bare_values, ":flse"}

#       json_string = "null,rue"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :multiple_bare_values, ",rue"}
#     end

#     test "invalid multiple bare values" do
#       json_string = "false true"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :multiple_bare_values, " true"}

#       json_string = "true:false"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, ":false"}

#       json_string = "null,true"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :multiple_bare_values, ",true"}
#     end
#   end

#   describe "negative numbers" do
#     test "parsing negative numbers is good and fine" do
#       json_string = "-1"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-1"

#       json_string = "-10920394059687"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-10920394059687"
#     end

#     test "int with error chars after" do
#       json_string = "-1;"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "-1;"}
#     end

#     test "int with exponent" do
#       json_string = "-1e40  "
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-1e40"

#       json_string = "-1E40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-1E40"
#     end

#     test "int with positive exponent" do
#       json_string = "-11e+2"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-11e+2"

#       json_string = "-11E+2"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-11E+2"
#     end

#     test "double e is wrong" do
#       json_string = "-11eE+2"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "-11eE+2"}

#       json_string = "-11Ee+2"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "-11Ee+2"}
#     end

#     test "letter is wrong" do
#       json_string = "-11eEa2"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "-11eEa2"}
#     end

#     test "negative decimal" do
#       json_string = "-1.5"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-1.5"
#     end

#     test "leading 0s are not allowed" do
#       json_string = "-01.5"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :leading_zero, "01.5"}

#       json_string = "-0001"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :leading_zero, "0001"}
#     end

#     test "white space for a bare value is no invalid" do
#       json_string = "-1.5   \n \t \r"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "-1.5"
#     end

#     test "invalid int" do
#       json_string = "-1.5;"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "-1.5;"}
#     end

#     test "multiple bare values is wrong?" do
#       json_string = "-1 -2 3 4 5"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "-1 -2 3 4 5"}

#       json_string = "-1.2 . -2.3 \n\t\r"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "-1.2 . -2.3 \n\t\r"}

#       json_string = "-1.2\n-2.3 \n\t\r"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "-1.2\n-2.3 \n\t\r"}
#     end
#   end

#   describe "positive numbers" do
#     test "numbers with 0s in" do
#       json_string = "102030405060708099887654321"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "102030405060708099887654321"
#     end

#     test "we can parse a number" do
#       json_string = "1"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "1"
#     end

#     test "we can parse a float" do
#       json_string = "1.500"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "1.500"
#     end

#     test "errors for both" do
#       json_string = "1;"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "1;"}

#       json_string = "1.5;"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "1.5;"}
#     end

#     test "exponents" do
#       json_string = "1.5e+40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "1.5e+40"

#       json_string = "1.5e-40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "1.5e-40"

#       json_string = "1.5E+40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "1.5E+40"

#       json_string = "1.5E-40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "1.5E-40"

#       json_string = "15e+40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "15e+40"

#       json_string = "15e-40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "15e-40"

#       json_string = "15E+40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "15E+40"

#       json_string = "15E-40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "15E-40"

#       json_string = "15ee+40"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :invalid_number, "15ee+40"}
#     end

#     test "leading 0s" do
#       json_string = "001"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :leading_zero, "001"}
#       json_string = "01.5"
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == {:error, :leading_zero, "01.5"}
#     end

#     test "multiple bare values is wrong?" do
#       json_string = "1 2 3 4 5"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "1 2 3 4 5"}

#       json_string = "1.2 . 2.3 \n\t\r"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "1.2 . 2.3 \n\t\r"}

#       json_string = "1.2\n2.3 \n\t\r"
#       acc = []

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :multiple_bare_values, "1.2\n2.3 \n\t\r"}
#     end
#   end

#   describe "strings" do
#     test "basic string" do
#       # These string escapes are for Elixir not JSON, so the parser just sees it as
#       # "[1,2,3,4]"
#       json_string = "\"[1, 2, 3, 4]\""
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "\"[1, 2, 3, 4]\""
#     end

#     test "escaped quotation mark in string" do
#       json_string = File.read!("./test/fixtures/escapes_string.json")
#       acc = []
#       assert Jxon.parse(json_string, TestHandler, acc) == "\"this is what he said: \\\"no\\\"\""
#     end

#     test "single backslash error" do
#       acc = []
#       json_string = ~s("\\ ")

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :unescaped_backslash, "\\ \"", ""}
#     end

#     test "When the string is not terminated we error" do
#       acc = []
#       json_string = ~s("\\")

#       assert Jxon.parse(json_string, TestHandler, acc) ==
#                {:error, :unterminated_string, 3, "\"\\\""}
#     end

#     test ~s("\\"\\\\\\/\\b\\f\\n\\r\\t") do
#       acc = []
#       json_string = ~s("\\"\\\\\\/\\b\\f\\n\\r\\t")
#       assert Jxon.parse(json_string, TestHandler, acc) == ~s("\\/\b\f\n\r\t)
#     end

#     test "unicode escapes don't actually escape, they just return as is" do
#       acc = []
#       json_string = ~s("\\u2603")
#       assert JxonIndexesUnoptimized.parse(json_string, TestHandler, 0, acc) == "\\u2603"
#       json_string = ~s("\\u2028\\u2029")
#       assert JxonIndexesUnoptimized.parse(json_string, TestHandler, 0, acc) == "\\u2028\\u2029"
#       json_string = ~s("\\uD834\\uDD1E")
#       assert JxonIndexesUnoptimized.parse(json_string, TestHandler, 0, acc) == "\\uD834\\uDD1E"
#       json_string = ~s("\\uD834\\uDD1E")
#       assert JxonIndexesUnoptimized.parse(json_string, TestHandler, 0, acc) == "\\uD834\\uDD1E"
#       json_string = ~s("\\uD799\\uD799")
#       assert JxonIndexesUnoptimized.parse(json_string, TestHandler, 0, acc) == "\\uD799\\uD799"
#       json_string = ~s("✔︎")
#       assert JxonIndexesUnoptimized.parse(json_string, TestHandler, 0, acc) == "✔︎"
#     end
#   end

#   # describe "arrays" do
#   #   test "we can parse a basic array" do
#   #     json_string = "[1, 2, 3, 4]"
#   #     acc = []
#   #     assert Jxon.parse(json_string, TestHandler, acc) == "[1, 2, 3, 4]"

#   #   end
#   # end

#   # for f <- File.ls!("/Users/Adz/Projects/jxon/test/test_parsing/") |> Enum.take(1) do
#   #   test "#{"/Users/Adz/Projects/jxon/test/test_parsing/" <> f}" do
#   #     fp = "/Users/Adz/Projects/jxon/test/test_parsing/" <> unquote(f)
#   #     json_string = File.read!(fp) |> IO.inspect(limit: :infinity, label: "ss")
#   #     acc = []
#   #     assert Jxon.parse(json_string, TestHandler, acc) == 1
#   #   end
#   # end
# end
