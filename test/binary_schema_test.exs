defmodule BinarySchemaTest do
  use ExUnit.Case, async: true

  describe "BinarySchema.contains" do
    # test "When we need to search for a sibling we do" do
    #   # This is the example JSON
    #   # json = ~s({"a" => {"b"=> 1 }, "c" => 2})
    #   schema = ~s({"a"6{"b"0}"c"0})
    #   # Current starts at + 1 here because we are imagining that we have already reacted to
    #   # the open {.
    #   bs = %BinarySchema{schema: schema, current: 1, collection_type: "{"}
    #   assert BinarySchema.contains?(bs, "c") == true
    # end

    # test "Finding a sibling with more children to skip" do
    #   # This is the example JSON
    #   # json = ~s({"a" => {"b"=> 1 }, "c" => 2})
    #   schema = ~s({"a"10{"bcdef"0}"c"0})
    #   # Current starts at + 1 here because we are imagining that we have already reacted to
    #   # the open {.
    #   bs = %BinarySchema{schema: schema, current: 1, collection_type: "{"}
    #   assert BinarySchema.contains?(bs, "c") == true
    # end

    # test "Finding the last sibling" do
    #   # This is the example JSON
    #   # json = ~s({"a" => {"b"=> 1 }, "c" => 2})
    #   schema = ~s({"a"10{"bcdef"0}"c"0"d"0"e"0})
    #   # Current starts at + 1 here because we are imagining that we have already reacted to
    #   # the open {.
    #   bs = %BinarySchema{schema: schema, current: 1, collection_type: "{"}
    #   assert BinarySchema.contains?(bs, "e") == true
    # end
  end
end
