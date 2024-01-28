defmodule SlimerHandler do
  @string :string
  @positive_number :positive_number
  @negative_number :negative_number
  @object_start :object_start
  @object_key :object_key
  @object_end :object_end
  @array_start :array_start
  @array_end :array_end
  # TODO change the above to this:
  # @string 0
  # @positive_number 1
  # @negative_number 2
  # @object_start 3
  # @object_key 4
  # @object_end 5
  # @array_start 6
  # @array_end 7

  @moduledoc """
  This is an experiment to see if we gain anything from having the stuff be one flat list
  of things. Here is an example output:

      json = "[true, false, null, 1, 2, 3, 4, 5]"

      [
        {:array_start, 0, 1},
        true,
        false,
        nil,
        {:positive_number, 20, 1},
        {:positive_number, 22, 1},
        {:positive_number, 25, 1},
        {:positive_number, 28, 1},
        {:positive_number, 31, 1},
        {:array_end, 32, 1}
      ]

  We now have to figure out a good way to ingest that and turn it into a DOM of some kind.
  Can we use schemas to filter down the data we keep? Do we have to verify it's correct.

  You might think you could store keys and values together but if you have nested objects
  or arrays then that means you tree becomes nested. Not sure if that would result in worse
  perf or not..
  """

  # How do we factor in the schemas then. We need to be able to traverse the schema in lock
  # step with the parsing of the fields. We could do this a few ways. One is to generate the
  # list of bytes as we do here, then have pass over it that constructs the structs and stuff.
  # OR we can try and put the schema here, and then skip the relevant parts. Let's try the latter
  # That will involve knowing when we can stop "skipping" which for lists might not be trivial.

  # First we need a path syntax. I guess it makes sense to borrow from Access a bit, but
  # we are going to alter it a bit to allow saying :all: (later we could add :first, :last)

  # ["object_key", 0, :all].

  # Wait does all always exist at the end of the path? I guess it's up to us if we want to
  # allow saying something like "get me all the object keys inside all the arrays", then get
  # me all of THEIR lists of stuff. But is this getting us into xpath territory... We could
  # enforce that if you do an {:all} you have to have an has_many or list_of. Essentially
  # your schema has to quite closely match the incoming data. Then if you wanted to flatten
  # it etc you'd do it in Elixir?

  # I think for the XML stuff that's the approach we took, which has the consequence that
  # you can generate schemas from an example data type. It also means you can do some interesting
  # validations on paths? Probs is faster in a superficial way because it kicks some stuff
  # down the road. But actually if we can tie in the "dont add it to acc unless I need it" then
  # we effectively filter down the data before searching.

  # The final boss is can we cast it into a struct, especially if we consider aggregates?

  def do_true(start_index, end_index, acc) when start_index <= end_index do
    [true | acc]
  end

  def do_false(start_index, end_index, acc) when start_index <= end_index do
    [false | acc]
  end

  def do_null(start_index, end_index, acc) when start_index <= end_index do
    [nil | acc]
  end

  def do_string(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - 1 - (start_index + 1) + 1
    [{@string, start_index + 1, len} | acc]
  end

  # Positive and negative numbers is not the distinction we care about. It's integers
  # and floats, most likely. We should emit a fn for float and one for integer. Ergh..
  def do_negative_number(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@negative_number, start_index, len} | acc]
  end

  def do_positive_number(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - start_index + 1
    [{@positive_number, start_index, len} | acc]
  end

  def start_of_object(_start_index, acc) do
    [@object_start | acc]
  end

  def object_key(start_index, end_index, acc) when start_index <= end_index do
    len = end_index - 1 - (start_index + 1) + 1
    [{@object_key, start_index + 1, len} | acc]
  end

  def end_of_object(_start_index, acc) do
    [@object_end | acc]
  end

  def start_of_array(_start_index, acc) do
    [@array_start | acc]
  end

  def end_of_array(_start_index, acc) do
    [@array_end | acc]
  end

  def end_of_document(_end_index, acc) do
    acc
  end
end
