defmodule JxonSlimOriginal do
  @moduledoc """
  This version is like using the binary matching but passes around the original so we can
  reference it to build a DOM.

  We should really compare this to I dunno chunking it off or whatever.
  """
  # " "
  @space <<0x20>>
  # \t
  @horizontal_tab <<0x09>>
  # \n
  @new_line <<0x0A>>
  # \r
  @carriage_return <<0x0D>>
  # Does this go in white space? I think it does...
  @form_feed <<0x0C>>
  @whitespace [@space, @horizontal_tab, @new_line, @carriage_return, @form_feed]
  @quotation_mark <<0x22>>
  @backslash <<0x5C>>
  @comma <<0x2C>>
  @colon <<0x3A>>
  @open_array <<0x5B>>
  @close_array <<0x5D>>
  @open_object <<0x7B>>
  @close_object <<0x7D>>
  @plus <<0x2B>>
  @minus <<0x2D>>
  @zero <<0x30>>
  @e <<0x65>>
  @capital_e <<0x45>>
  @digits [
    <<0x31>>,
    <<0x32>>,
    <<0x33>>,
    <<0x34>>,
    <<0x35>>,
    <<0x36>>,
    <<0x37>>,
    <<0x38>>,
    <<0x39>>
  ]
  @all_digits [@zero | @digits]
  @decimal_point <<0x2E>>
  # Escape next chars
  # @u <<0x75>>
  # @b <<0x62>>
  @f <<0x66>>
  @n <<0x6E>>
  # @r <<0x72>>
  @t <<0x74>>
  @value_indicators [
                      @quotation_mark,
                      @open_array,
                      @open_object,
                      @minus,
                      @zero,
                      @f,
                      @n,
                      @t
                    ] ++ @digits
  @array 0
  @object 1

  # OKAY So this is a good read. https://rhye.org/post/erlang-binary-matching-performance/

  def parse(<<>>, original, handler, current_index, acc) do
    handler.end_of_document(original, current_index - 1, acc)
  end

  for space <- @whitespace do
    def parse(<<unquote(space), rest::binary>>, original, handler, current_index, acc) do
      parse(rest, original, handler, current_index + 1, acc)
    end
  end

  def parse(<<@open_object, rest::bits>> = j, original, handler, current_index, acc) do
    case parse_object(rest, original, handler, current_index + 1, acc, [{@object, 1}]) do
      {:error, _, _} = error ->
        error

      {end_index, acc, []} ->
        <<_rest::binary-size(end_index - current_index), actual_rest::bits>> = j
        parse_remaining_whitespace(actual_rest, original, end_index, acc, handler)
    end
  end

  def parse(<<@open_array, rest::bits>> = j, original, handler, current_index, acc) do
    case parse_array(rest, original, handler, current_index + 1, acc, [{@array, 1}]) do
      {:error, _, _} = error ->
        error

      {end_index, acc, []} ->
        <<_skip::binary-size(end_index - current_index), the_rest::bits>> = j
        parse_remaining_whitespace(the_rest, original, end_index, acc, handler)
    end
  end

  for digit <- @all_digits do
    def parse(<<@zero, unquote(digit), _rest::bits>>, _, _, current_index, _) do
      {:error, :leading_zero, current_index}
    end
  end

  for digit <- @all_digits do
    def parse(<<@minus, @zero, unquote(digit), _rest::bits>>, _, _, current_index, _) do
      {:error, :leading_zero, current_index + 1}
    end
  end

  for digit <- @all_digits do
    def parse(<<@minus, unquote(digit), number::bits>> = j, original, handler, current_index, acc) do
      case parse_number(number, current_index + 2, current_index, original, handler, acc) do
        {:error, _, _} = error ->
          error

        {end_index, acc} ->
          <<_skip::binary-size(end_index - current_index), after_numb::bits>> = j
          parse_remaining_whitespace(after_numb, original, end_index, acc, handler)
      end
    end
  end

  def parse(<<@minus>>, _, _, current_index, _) do
    {:error, :invalid_json_character, current_index}
  end

  def parse(<<@minus, _rest::bits>>, _, _, current_index, _) do
    {:error, :invalid_json_character, current_index + 1}
  end

  for digit <- @all_digits do
    def parse(<<unquote(digit), rest::bits>> = j, original, handler, current_index, acc) do
      case parse_number(rest, current_index + 1, current_index, original, handler, acc) do
        {:error, _, _} = error ->
          error

        {end_index, acc} ->
          <<_skip::binary-size(end_index - current_index), rest::bits>> = j
          parse_remaining_whitespace(rest, original, end_index, acc, handler)
      end
    end
  end

  def parse(<<@quotation_mark, rest::bits>> = j, original, handler, current_index, acc) do
    case parse_string(rest, current_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        <<_skip::binary-size(end_index - current_index), rest::bits>> = j

        case handler.do_string(original, current_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> parse_remaining_whitespace(rest, original, end_index, acc, handler)
        end
    end
  end

  def parse(<<@t, rest::bits>> = j, original, handler, start_index, acc) do
    case parse_true(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        <<_skip::binary-size(end_index - start_index), rest::bits>> = j

        case handler.do_true(original, start_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> parse_remaining_whitespace(rest, original, end_index, acc, handler)
        end
    end
  end

  def parse(<<@f, rest::bits>> = j, original, handler, start_index, acc) do
    case parse_false(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        <<_skip::binary-size(end_index - start_index), rest::bits>> = j

        case handler.do_true(original, start_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> parse_remaining_whitespace(rest, original, end_index, acc, handler)
        end
    end
  end

  def parse(<<@n, rest::bits>> = j, original, handler, start_index, acc) do
    case parse_null(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        <<_skip::binary-size(end_index - start_index), rest::bits>> = j

        case handler.do_null(original, start_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> parse_remaining_whitespace(rest, original, end_index, acc, handler)
        end
    end
  end

  def parse(<<_byte::binary-size(1), _rest::bits>>, _, _handler, current_index, _acc) do
    {:error, :invalid_json_character, current_index}
  end

  defp parse_object(<<rest::binary>>, original, handler, current_index, acc, depth_stack) do
    case handler.start_of_object(original, current_index - 1, acc) do
      {:error, _, _} = error ->
        error

      acc ->
        end_index = skip_whitespace(rest, current_index)
        <<_skip::binary-size(end_index - current_index), rest::bits>> = rest
        key_value(rest, original, handler, end_index, acc, depth_stack)
    end
  end

  defp key_value(<<@close_object, rest::bits>>, original, handler, index, acc, depth_stack) do
    close_object(rest, original, handler, index, acc, depth_stack)
  end

  defp key_value(<<rest::binary>>, original, handler, current_index, acc, depth_stack) do
    case parse_object_key(rest, original, handler, current_index, acc) do
      {:error, _, _} = error ->
        error

      {key_end_index, acc} ->
        <<_skip::binary-size(key_end_index - current_index), after_obj_key::bits>> = rest
        whitespace_end_index = skip_whitespace(after_obj_key, key_end_index)
        <<_skip::binary-size(whitespace_end_index - key_end_index), rest::bits>> = after_obj_key

        case parse_value(rest, original, handler, whitespace_end_index, acc, depth_stack) do
          {:error, _, _} = error ->
            error

          {comma_start, acc, depth_stack} ->
            <<_skip::binary-size(comma_start - whitespace_end_index), rest::bits>> = rest

            case parse_comma(rest, comma_start, depth_stack) do
              {:error, _, _} = error ->
                error

              end_index ->
                <<_skip::binary-size(end_index - comma_start), rest::bits>> = rest
                after_whitespace_index = skip_whitespace(rest, end_index)

                <<_::binary-size(after_whitespace_index - end_index), after_whitespace::bits>> =
                  rest

                case after_whitespace do
                  # Parse comma returns the closing element that it finds. That can be any of:
                  # close object, comma, or a close array. If we are parsing a key/value then the
                  # allowed values are comma, close object, or an actual value. That means if
                  # we parse comma and see a closing array well something fucked up.

                  # If we see a close object though we are going to recur and key/value deals with it.
                  <<@close_array, _::bits>> ->
                    {:error, :unclosed_object, end_index - 1}

                  _ ->
                    key_value(
                      after_whitespace,
                      original,
                      handler,
                      after_whitespace_index,
                      acc,
                      depth_stack
                    )
                end
            end
        end
    end
  end

  defp parse_object_key(
         <<@quotation_mark, rest::bits>> = j,
         original,
         handler,
         current_index,
         acc
       ) do
    case parse_string(rest, current_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        <<_skip::binary-size(end_index - current_index), after_string::bits>> = j

        case handler.object_key(original, current_index, end_index - 1, acc) do
          {:error, _, _} = error ->
            error

          acc ->
            case parse_colon(after_string, end_index) do
              {:error, _, _} = error -> error
              end_index -> {end_index, acc}
            end
        end
    end
  end

  defp parse_object_key(<<>>, _, _handler, index, _acc) do
    {:error, :invalid_object_key, index - 1}
  end

  defp parse_object_key(<<_rest::binary>>, _, _handler, index, _acc) do
    {:error, :invalid_object_key, index}
  end

  defp parse_array(<<array_contents::binary>>, original, handler, current_index, acc, depth_stack) do
    # current index points to head of array_contents, we want the char before ie the '['
    case handler.start_of_array(original, current_index - 1, acc) do
      {:error, _, _} = error ->
        error

      acc ->
        end_index = skip_whitespace(array_contents, current_index)
        <<_::binary-size(end_index - current_index), after_whitespace::bits>> = array_contents

        case after_whitespace do
          <<@comma, _::bits>> ->
            {:error, :leading_comma, end_index}

          after_whitespace ->
            case parse_values(after_whitespace, original, handler, end_index, acc, depth_stack) do
              # Here we want to be like "if we see a comma then recur".
              {:error, _, _} = error -> error
              {end_index, acc, depth_stack} -> {end_index, acc, depth_stack}
            end
        end
    end
  end

  defp parse_values(<<@close_array, _rest::bits>>, original, handler, index, acc, [
         {@array, array_depth} | rest_depth
       ]) do
    new_array_depth = array_depth - 1

    if new_array_depth < 0 do
      {:error, :unopened_array, index}
    else
      case handler.end_of_array(original, index, acc) do
        {:error, _, _} = error ->
          error

        acc ->
          if new_array_depth == 0 do
            {index + 1, acc, rest_depth}
          else
            {index + 1, acc, [{@array, new_array_depth} | rest_depth]}
          end
      end
    end
  end

  defp parse_values(<<rest::binary>>, original, handler, current_index, acc, depth_stack) do
    case parse_value(rest, original, handler, current_index, acc, depth_stack) do
      {:error, _, _} = error ->
        error

      {value_end_index, acc, depth_stack} ->
        <<_skip::binary-size(value_end_index - current_index), rest::bits>> = rest

        # The expected result from parse_values here is EITHER a comma or a close array.
        # There could be whitespace after the comma.
        case parse_comma(rest, value_end_index, depth_stack) do
          {:error, _, _} = error ->
            error

          end_index ->
            <<_skip::binary-size(end_index - value_end_index), rest::bits>> = rest
            after_whitespace_index = skip_whitespace(rest, end_index)
            <<_::binary-size(after_whitespace_index - end_index), after_whitespace::bits>> = rest

            case after_whitespace do
              # The situation here is you have closed the object before an array but you can never
              # get here because you get a different error first.
              <<@close_object, _rest::bits>> ->
                raise "hell"

              _ ->
                parse_values(
                  after_whitespace,
                  original,
                  handler,
                  after_whitespace_index,
                  acc,
                  depth_stack
                )
            end
        end
    end
  end

  defp parse_value(
         <<@open_array, rest::bits>>,
         original,
         handler,
         index,
         acc,
         [head_depth | rest_depth] = depth_stack
       ) do
    case head_depth do
      {@object, _count} ->
        parse_array(rest, original, handler, index + 1, acc, [{@array, 1} | depth_stack])

      {@array, count} ->
        parse_array(rest, original, handler, index + 1, acc, [{@array, count + 1} | rest_depth])
    end
  end

  defp parse_value(
         <<@open_object, rest::bits>>,
         original,
         handler,
         index,
         acc,
         [head_depth | rest_depth] = depth_stack
       ) do
    case head_depth do
      {@object, count} ->
        parse_object(rest, original, handler, index + 1, acc, [{@object, count + 1} | rest_depth])

      {@array, _count} ->
        parse_object(rest, original, handler, index + 1, acc, [{@object, 1} | depth_stack])
    end
  end

  defp parse_value(<<@close_object, rest::bits>>, original, handler, index, acc, depth_stack) do
    close_object(rest, original, handler, index, acc, depth_stack)
  end

  defp parse_value(
         <<@quotation_mark, rest::bits>>,
         original,
         handler,
         current_index,
         acc,
         depth_stack
       ) do
    case parse_string(rest, current_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        case handler.do_string(original, current_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> {end_index, acc, depth_stack}
        end
    end
  end

  for space <- @whitespace do
    defp parse_value(<<unquote(space), rest::binary>>, original, handler, index, acc, depth_stack) do
      parse_value(rest, original, handler, index + 1, acc, depth_stack)
    end
  end

  for digit <- @all_digits do
    defp parse_value(<<@zero, unquote(digit), _::bits>>, _, _, current_index, _, _) do
      {:error, :leading_zero, current_index}
    end
  end

  for next <- @all_digits do
    defp parse_value(<<@minus, @zero, unquote(next), _rest::bits>>, _, _, current_index, _, _) do
      # This points to the 0 and not the '-'
      {:error, :leading_zero, current_index + 1}
    end
  end

  for digit <- @all_digits do
    defp parse_value(
           <<@minus, unquote(digit), number::bits>>,
           original,
           handler,
           current_index,
           acc,
           depth_stack
         ) do
      case parse_number(number, current_index + 2, current_index, original, handler, acc) do
        {:error, _, _} = error -> error
        {end_index, acc} -> {end_index, acc, depth_stack}
      end
    end
  end

  defp parse_value(<<@minus>>, _, _, current_index, _, _) do
    {:error, :invalid_json_character, current_index}
  end

  defp parse_value(<<@minus, _rest::bits>>, _, _, current_index, _, _) do
    {:error, :invalid_json_character, current_index + 1}
  end

  for digit <- @all_digits do
    defp parse_value(
           <<unquote(digit), _::bits>> = json,
           original,
           handler,
           current_index,
           acc,
           depth_stack
         ) do
      case parse_number(json, current_index, current_index, original, handler, acc) do
        {:error, _, _} = error -> error
        {end_index, acc} -> {end_index, acc, depth_stack}
      end
    end
  end

  defp parse_value(<<@t, rest::bits>>, original, handler, start_index, acc, depth_stack) do
    case parse_true(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        case handler.do_true(original, start_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> {end_index, acc, depth_stack}
        end
    end
  end

  defp parse_value(<<@f, rest::bits>>, original, handler, start_index, acc, depth_stack) do
    case parse_false(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        case handler.do_false(original, start_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> {end_index, acc, depth_stack}
        end
    end
  end

  defp parse_value(<<@n, rest::bits>>, original, handler, start_index, acc, depth_stack) do
    case parse_null(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      end_index ->
        case handler.do_null(original, start_index, end_index - 1, acc) do
          {:error, _, _} = error -> error
          acc -> {end_index, acc, depth_stack}
        end
    end
  end

  defp parse_value(<<>>, _, _handler, end_index, acc, []) do
    {end_index - 1, acc, []}
  end

  defp parse_value(<<>>, _, _handler, end_index, _acc, depth_stack) do
    case hd(depth_stack) do
      # I don't think we can actually hit this case because we check for valid keys
      # immediately after the object open.
      {@object, _count} -> {:error, :unclosed_object, end_index - 1}
      {@array, _count} -> {:error, :unclosed_array, end_index - 1}
    end
  end

  for byte <- @value_indicators do
    defp parse_value(<<unquote(byte), _::bits>>, _, _, problematic_char_index, _, _) do
      {:error, :multiple_bare_values, problematic_char_index}
    end
  end

  defp parse_value(<<_rest::binary>>, _, _handler, index, _acc, _) do
    {:error, :invalid_json_character, index}
  end

  defp close_object(<<_rest::binary>>, original, handler, index, acc, [
         {@object, object_depth} | rest_depth
       ]) do
    new_object_depth = object_depth - 1

    if new_object_depth < 0 do
      {:error, :unopened_object, index}
    else
      case handler.end_of_object(original, index, acc) do
        {:error, _, _} = error ->
          error

        acc ->
          if new_object_depth == 0 do
            {index + 1, acc, rest_depth}
          else
            {index + 1, acc, [{@object, new_object_depth} | rest_depth]}
          end
      end
    end
  end

  defp close_object(<<_::binary>>, _, _, index, _, [{@array, _} | _]) do
    {:error, :unclosed_array, index - 1}
  end

  defp parse_colon(<<rest::binary>>, current_index) do
    whitespace_index = skip_whitespace(rest, current_index)
    <<_::binary-size(whitespace_index - current_index), after_whitespace::bits>> = rest

    case after_whitespace do
      <<@colon, rest::bits>> = j ->
        end_index = skip_whitespace(rest, whitespace_index + 1)
        <<_::binary-size(end_index - whitespace_index), after_whitespace::bits>> = j

        case after_whitespace do
          <<@close_array, _rest::bits>> -> {:error, :unopened_array, end_index}
          <<@close_object, _rest::bits>> -> {:error, :missing_object_value, end_index - 1}
          <<@colon, _rest::bits>> -> {:error, :double_colon, end_index}
          <<@comma, _rest::bits>> -> {:error, :missing_object_value, end_index - 1}
          "" -> {:error, :missing_object_value, end_index - 1}
          _ -> end_index
        end

      _ ->
        {:error, :missing_key_value_separator, whitespace_index}
    end
  end

  defp parse_comma(<<rest::binary>>, current_index, depth_stack) do
    whitespace_index = skip_whitespace(rest, current_index)
    <<_::binary-size(whitespace_index - current_index), after_whitespace::bits>> = rest

    case after_whitespace do
      <<@comma, rest::bits>> = j ->
        end_index = skip_whitespace(rest, whitespace_index + 1)
        <<_::binary-size(end_index - whitespace_index), after_whitespace::bits>> = j

        case after_whitespace do
          <<@comma, _rest::bits>> ->
            {:error, :double_comma, end_index}

          <<@close_array, _rest::bits>> ->
            {:error, :trailing_comma, whitespace_index}

          <<@close_object, _rest::bits>> ->
            {:error, :trailing_comma, whitespace_index}

          "" ->
            case hd(depth_stack) do
              {@object, _count} -> {:error, :unclosed_object, end_index - 1}
              {@array, _count} -> {:error, :unclosed_array, end_index - 1}
            end

          _ ->
            end_index
        end

      "" ->
        case hd(depth_stack) do
          {@object, _count} -> {:error, :unclosed_object, current_index - 1}
          {@array, _count} -> {:error, :unclosed_array, current_index - 1}
        end

      <<@close_array, _rest::bits>> ->
        current_index

      <<@close_object, _rest::bits>> ->
        current_index

      <<byte::binary-size(1), _rest::bits>> when byte in @value_indicators ->
        {:error, :multiple_bare_values, current_index + 1}

      _ ->
        {:error, :invalid_json_character, current_index + 1}
    end
  end

  defp parse_true(<<"rue"::binary, _rest::bits>>, current_index) do
    current_index + 3
  end

  defp parse_true(<<"ru"::binary, _rest::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 2}
  end

  defp parse_true(<<"r"::binary, _::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 1}
  end

  defp parse_true(<<_::binary>>, current_index) do
    {:error, :invalid_boolean, current_index}
  end

  defp parse_false(<<"alse"::binary, _rest::bits>>, current_index) do
    current_index + 4
  end

  defp parse_false(<<"als"::binary, _::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 3}
  end

  defp parse_false(<<"al"::binary, _::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 2}
  end

  defp parse_false(<<"a"::binary, _::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 1}
  end

  defp parse_false(<<_::binary>>, current_index), do: {:error, :invalid_boolean, current_index}

  # We already know there is an 'n' because that's how we decided to call this fn. In the
  # happy case we want to point to the last 'l' + 1 so that we maintain the invariant that
  # the index always points to the head of rest. It means on success we want to - 1 to get
  # the end of the value. But that's fine.

  # In the error case we want to point to the first erroneous char, which is one after the
  # match.
  defp parse_null(<<"ull"::binary, _rest::bits>>, current_index) do
    current_index + 3
  end

  defp parse_null(<<"ul"::binary, _::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 2}
  end

  defp parse_null(<<"u"::binary, _::bits>>, current_index) do
    {:error, :invalid_boolean, current_index + 1}
  end

  defp parse_null(<<_::binary>>, current_index), do: {:error, :invalid_boolean, current_index}

  for space <- @whitespace do
    defp skip_whitespace(<<unquote(space), rest::binary>>, index) do
      skip_whitespace(rest, index + 1)
    end
  end

  defp skip_whitespace(<<_remaining::binary>>, index), do: index

  # What happens if the backslash is escaped? Should be an error... no?
  defp parse_string(<<@backslash, @backslash, @quotation_mark, _::bits>>, end_character_index) do
    {:error, :unescaped_quotation_mark, end_character_index + 2}
  end

  defp parse_string(<<@backslash, @quotation_mark, rest::bits>>, end_character_index) do
    parse_string(rest, end_character_index + 2)
  end

  defp parse_string(<<@quotation_mark, _rest::bits>>, end_character_index) do
    # This means we keep the invariant that index points to the head of rest. But means
    # (because we are not emitting here) that we have to - 1 from the index when we emit in
    # the caller.
    end_character_index + 1
  end

  defp parse_string(<<_byte::binary-size(1), rest::bits>>, end_character_index) do
    parse_string(rest, end_character_index + 1)
  end

  defp parse_string(<<>>, end_character_index) do
    {:error, :unterminated_string, end_character_index - 1}
  end

  # We'd like to know when we are parsing a float.
  for digit <- @all_digits do
    defp parse_number(
           <<@decimal_point, unquote(digit), rest::bits>>,
           current_index,
           start_index,
           original,
           handler,
           acc
         ) do
      parse_fractional_digits(rest, current_index + 2, start_index, original, handler, acc)
    end
  end

  defp parse_number(<<@decimal_point, _rest::bits>>, current_index, _, _, _, _) do
    {:error, :invalid_decimal_number, current_index + 1}
  end

  for exp <- [@e, @capital_e] do
    defp parse_number(
           <<unquote(exp), rest::bits>>,
           current_index,
           start_index,
           original,
           handler,
           acc
         ) do
      case parse_exponent(rest, current_index + 1) do
        {:error, _, _} = error ->
          error

        end_index ->
          case handler.do_integer(original, start_index, end_index - 1, acc) do
            {:error, _, _} = error -> error
            acc -> {end_index, acc}
          end
      end
    end
  end

  for digit <- @all_digits do
    defp parse_number(
           <<unquote(digit), rest::bits>>,
           current_index,
           start_index,
           original,
           handler,
           acc
         ) do
      parse_number(rest, current_index + 1, start_index, original, handler, acc)
    end
  end

  defp parse_number(_, end_index, start_index, original, handler, acc) do
    case handler.do_integer(original, start_index, end_index - 1, acc) do
      {:error, _, _} = error -> error
      acc -> {end_index, acc}
    end
  end

  for digit <- @all_digits do
    defp parse_fractional_digits(
           <<unquote(digit), rest::bits>>,
           current_index,
           start_index,
           original,
           handler,
           acc
         ) do
      parse_fractional_digits(rest, current_index + 1, start_index, original, handler, acc)
    end
  end

  for exp <- [@e, @capital_e] do
    defp parse_fractional_digits(
           <<unquote(exp), rest::bits>>,
           current_index,
           start_index,
           original,
           handler,
           acc
         ) do
      case parse_exponent(rest, current_index + 1) do
        {:error, _, _} = error ->
          error

        end_index ->
          case handler.do_float(original, start_index, end_index - 1, acc) do
            {:error, _, _} = error -> error
            acc -> {end_index, acc}
          end
      end
    end
  end

  defp parse_fractional_digits(_, end_index, start_index, original, handler, acc) do
    case handler.do_float(original, start_index, end_index - 1, acc) do
      {:error, _, _} = error -> error
      acc -> {end_index, acc}
    end
  end

  for digit <- @all_digits do
    defp parse_digits(<<unquote(digit), rest::bits>>, index) do
      parse_digits(rest, index + 1)
    end
  end

  defp parse_digits(<<_rest::binary>>, index), do: index

  for sign <- [@plus, @minus], digit <- @all_digits do
    defp parse_exponent(<<unquote(sign), unquote(digit), rest::bits>>, index) do
      parse_digits(rest, index + 2)
    end
  end

  for digit <- @all_digits do
    defp parse_exponent(<<unquote(digit), rest::bits>>, index) do
      parse_digits(rest, index + 1)
    end
  end

  defp parse_exponent(<<_rest::binary>>, index) do
    {:error, :invalid_exponent, index}
  end

  for head <- @whitespace do
    defp parse_remaining_whitespace(
           <<unquote(head), rest::binary>>,
           original,
           index,
           acc,
           handler
         ) do
      parse_remaining_whitespace(rest, original, index + 1, acc, handler)
    end
  end

  defp parse_remaining_whitespace(<<>>, original, index, acc, handler) do
    handler.end_of_document(original, index - 1, acc)
  end

  for byte <- @value_indicators do
    defp parse_remaining_whitespace(<<unquote(byte), _::bits>>, _, index, _, _) do
      {:error, :multiple_bare_values, index}
    end
  end

  defp parse_remaining_whitespace(<<_rest::binary>>, _, index, _, _) do
    {:error, :invalid_json_character, index}
  end
end
