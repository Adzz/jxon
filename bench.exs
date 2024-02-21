# DATA Schema modules defined in jxon/lib/json_schema.ex
decode_jobs = %{
  "Jason" => fn json ->
    Jason.decode!(json) |> DataSchema.to_struct(ExampleDataSchema)
    # Jason.decode!(json) |> DataSchema.to_struct(CanadaSchema)
  end,
  "Poison" => fn json ->
    Poison.decode!(json) |> DataSchema.to_struct(ExampleDataSchema)
    # Poison.decode!(json) |> DataSchema.to_struct(CanadaSchema)
  end,
  # "JSX" => fn json -> JSX.decode!(json, [:strict]) end,
  # "Tiny" => fn json -> Tiny.decode!(json) end,
  # "jsone" => fn json -> :jsone.decode(json) end,
  # "jiffy" => fn json -> :jiffy.decode(json, [:return_maps, :use_nil]) end,
  # "JSON" => fn json -> JSON.decode!(json) end
  # "JxonIndexesUnoptimized" => fn json -> JxonIndexesUnoptimized.parse(json, TestHandler, 0, []) end,
  # "JXON cast" => fn json -> JxonIndexesUnoptimized.parse(json, CastingHandler, 0, []) end,
  # "JXON slim" => fn json -> JxonSlim.parse(json, SlimHandler, 0, []) end,
  # "JXON slimer" => fn json -> JxonSlim.parse(json, SlimerHandler, 0, []) end,
  # "JxonSlimOriginal" => fn json ->
  #   JxonSlimOriginal.parse(json, json, OriginalSlimHandler, 0, [])
  # end
  "Adz's attempt" => fn json ->
    # Github schema
    acc = {%Schema{current: nil, schema: %{all: %{object: %{"comments_url" => true}}}}, []}

    # canada schema
    # acc =
    #   {%Schema{
    #      current: nil,
    #      schema: %{
    #        object: %{
    #          "type" => true,
    #          "features" => %{
    #            all: %{
    #              object: %{
    #                "type" => true,
    #                "geometry" => %{
    #                  object: %{"type" => true}
    #                },
    #                "properties" => %{object: %{"name" => true}}
    #              }
    #            }
    #          }
    #        }
    #      }
    #    }, []}

    JxonSlimOriginal.parse(json, json, OriginalSlimWithSchema, 0, acc)
    # |> DataSchema.to_struct(CanadaSchema)
    |> DataSchema.to_struct(ExampleDataSchema)
  end
  # "binary_to_term/1" => fn {_, etf} -> :erlang.binary_to_term(etf) end,
}

decode_inputs = [
  "GitHub"
  # "Giphy",
  # GovTrack is 3.9mb file.
  # "GovTrack"
  # "canada"
  # "Blockchain",
  # "Pokedex",
  # "JSON Generator",
  # "JSON Generator (Pretty)",
  # "UTF-8 escaped",
  # "UTF-8 unescaped",
  # "Issue 90"
]

read_data = fn name ->
  file =
    name
    |> String.downcase()
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")

  File.read!(Path.expand("./bench/data/#{file}.json", __DIR__))
end

inputs = for name <- decode_inputs, into: %{}, do: {name, read_data.(name)}

Benchee.run(decode_jobs,
  #  parallel: 4,
  warmup: 5,
  time: 30,
  memory_time: 1,
  inputs: inputs,
  formatters: [
    Benchee.Formatters.Console
  ]
)
