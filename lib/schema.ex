defmodule Schema do
  @moduledoc """
  An experimental module to let us iterate on what a good data structure would look like
  for querying paths when we parse the JSON.

  Some early thoughts are that we could maybe use a flat array and do like pointer/index
  math to figure out how many we have to jump in order to find a sibling.
  This might require a couple of passes when generating the schema paths but that's fine.

  Another option is to just try using an existing zipper lib?
  Another option is to try nested maps that we take apart and put back together again?
  """
end
