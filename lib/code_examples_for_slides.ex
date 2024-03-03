# defmodule CodeExamplesForSlides do
#   @quotation_mark <<0x22>>

#   def parse(json, handler, start_index, acc) do
#     # ...
#   end

#   def parse(
#         <<@quotation_mark, rest::bits>>,
#         original,
#         handler,
#         current_index,
#         acc
#       ) do
#     {rest, end_index, acc} = parse_string(rest, current_index + 1, handler, acc)
#     # ...
#   end

#   def parse(
#         <<@quotation_mark, rest::bits>> = json,
#         original,
#         handler,
#         current_index,
#         acc
#       ) do
#     end_index = parse_string(rest, current_index + 1)
#     <<_skip::binary-size(end_index - current_index), rest::bits>> = json
#     handler.handle_string(original, current_index, end_index, acc)
#     # ...
#   end

# end
