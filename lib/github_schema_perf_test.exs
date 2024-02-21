defmodule GithubSchemaPerfTest do
  @moduledoc """
  Here we are going to setup some things to performance test Jason and Poison
  against this JSON parser. With the massive caveat that we aren't string escaping.
  ... Anyway...


  For now the test will be to take the github.json file and return a struct of some
  subset of that data. For Jason et al the test will be:

    1. Parse the entire file
    2. Use DataSchema to query for the subset we want.

  For our parser we will instead:

    1. Generate the schema (this wont be part of the perf test of course)
    2. Run the OriginalSlimWithSchema parsing thing.
    3. Use DataSchema to query for the subset we want.

  The idea being in our parser there should be a lot less data that data schema has to query.

  It would be cool if we could eventually get structs straight out of the parser. That definitely
  feels possible but yea who knows.
  """

  def schema do
    # Let's start simple
    %Schema{current: nil, schema: %{all: %{"comments_url" => true}}}
  end
end
