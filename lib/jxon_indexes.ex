defmodule JxonIndexes do
  @moduledoc """
  This version of the parser supplies start and end indexes to each of the callbacks and
  the original binary. That allows callers to implement callbacks that access the parts of
  the binary they care about and choose to copy or reference the original binary.

  This is a currently untested sketch. It's probably off by one in a few places.
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
  @forwardslash <<0x2F>>
  @comma <<0x2C>>
  @colon <<0x3A>>
  @open_array <<0x5B>>
  @close_array <<0x5D>>
  @open_object <<0x7B>>
  @close_object <<0x7D>>
  @plus <<0x2B>>
  @minus <<0x2D>>
  @zero <<0x30>>
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
  @u <<0x75>>
  @b <<0x62>>
  @f <<0x66>>
  @n <<0x6E>>
  @r <<0x72>>
  @t <<0x74>>
  @valid_json_chars [
                      @decimal_point,
                      @quotation_mark,
                      @backslash,
                      @forwardslash,
                      @comma,
                      @colon,
                      @open_array,
                      # @close_array,
                      @open_object,
                      # @close_object,
                      @plus,
                      @minus,
                      @zero,
                      # f n and t are for the start of false, true and null
                      @f,
                      @n,
                      @t
                    ] ++ @digits ++ @whitespace
  @doc """
  """
  # we should not have to pass in the current_index ? I wonder if it enables parsing part
  # of a document though. Like you could split it up and try it, or parse from a specific point
  # onwards.
  def parse(document, handler, current_index, acc) do
    parse(document, document, handler, current_index, acc)
  end

  def parse(<<>>, original, handler, current_index, acc) do
    handler.end_of_document(original, current_index, acc)
  end

  def parse(@space <> rest, original, handler, current_index, acc) do
    parse(rest, original, handler, current_index + 1, acc)
  end

  def parse(@horizontal_tab <> rest, original, handler, current_index, acc) do
    parse(rest, original, handler, current_index + 1, acc)
  end

  def parse(@new_line <> rest, original, handler, current_index, acc) do
    parse(rest, original, handler, current_index + 1, acc)
  end

  def parse(@carriage_return <> rest, original, handler, current_index, acc) do
    parse(rest, original, handler, current_index + 1, acc)
  end

  def parse(<<@open_array, rest::bits>>, original, handler, current_index, acc) do
    # Last arg is depth.
    case parse_array(rest, original, handler, current_index + 1, acc, 1) do
      {:error, _, _} = error -> error
      {end_index, rest, acc} -> parse(rest, original, handler, end_index, acc)
    end
  end

  # Leading zeros are prohibited!!
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON

  # TODO: test parsing the number 0 which is allowed, of course.
  def parse(<<@zero, _rest::bits>>, _original, _handler, current_index, _acc) do
    # Would it be good for handlers to be able do this optionally? Like as an extension
    # allow leading 0s in integers or something. Seems like that would be good... To do
    # that we could call the handler and then case on the return value to decide wither we
    # continue or not. In reality we could do that anyway everywhere we call the handler and
    # have a haltable / continueable json parser. We will circle back to this.
    {:error, :leading_zero, current_index}
  end

  def parse(<<@minus, @zero, _rest::bits>>, _original, _handler, current_index, _acc) do
    # This points to the 0 and not the '-'
    {:error, :leading_zero, current_index + 1}
  end

  def parse(
        <<@minus, digit::binary-size(1), number::bits>>,
        original,
        handler,
        current_index,
        acc
      )
      when digit in @digits do
    case parse_number(number, current_index + 2) do
      {end_index, ""} ->
        acc = handler.do_negative_number(original, current_index, end_index, acc)
        handler.end_of_document(original, end_index, acc)

      {end_index, remaining} ->
        acc = handler.do_negative_number(original, current_index, end_index - 1, acc)
        parse_remaining_whitespace(remaining, end_index, original, acc, handler)

      {:error, _, _} = error ->
        error
    end
  end

  def parse(<<@minus, _::bits>>, _original, _handler, current_index, _acc) do
    # We could special case and point at the whitespace after the minus in the future.
    {:error, :invalid_json_character, current_index}
  end

  def parse(<<byte::binary-size(1), rest::bits>>, original, handler, current_index, acc)
      when byte in @digits do
    case parse_number(rest, current_index + 1) do
      {end_index, ""} ->
        acc = handler.do_positive_number(original, current_index, end_index, acc)
        handler.end_of_document(original, end_index, acc)

      {end_index, remaining} ->
        acc = handler.do_positive_number(original, current_index, end_index - 1, acc)
        parse_remaining_whitespace(remaining, end_index, original, acc, handler)

      {:error, _, _} = error ->
        error
    end
  end

  def parse(<<@quotation_mark, rest::bits>>, original, handler, current_index, acc) do
    case find_string_end(rest, current_index + 1) do
      {:error, :unterminated_string, problematic_char_index} ->
        {:error, :unterminated_string, problematic_char_index}

      # The end index here is the index one BEFORE the closing '"' because we don't send the
      # quotes to the handler. which means we + 1 when calling the end of the document.
      {end_index, ""} ->
        acc = handler.do_string(original, current_index + 1, end_index, acc)
        handler.end_of_document(original, end_index + 1, acc)

      {end_index, remaining} ->
        acc = handler.do_string(original, current_index + 1, end_index, acc)
        # Add 1 for the '"' and 1 to be at the char _after_ that.
        parse_remaining_whitespace(remaining, end_index + 2, original, acc, handler)

      {:error, _, _} = error ->
        error
    end
  end

  def parse("true", original, handler, current_index, acc) do
    end_index = current_index + 3
    acc = handler.do_true(original, current_index, end_index, acc)
    handler.end_of_document(original, end_index, acc)
  end

  def parse("false", original, handler, current_index, acc) do
    end_index = current_index + 4
    acc = handler.do_false(original, current_index, end_index, acc)
    handler.end_of_document(original, end_index, acc)
  end

  def parse("null", original, handler, current_index, acc) do
    end_index = current_index + 3
    acc = handler.do_null(original, current_index, end_index, acc)
    handler.end_of_document(original, end_index, acc)
  end

  def parse("null" <> rest, original, handler, current_index, acc) do
    end_index = current_index + 3
    acc = handler.do_null(original, current_index, end_index, acc)
    parse_remaining_whitespace(rest, end_index + 1, original, acc, handler)
  end

  def parse("true" <> rest, original, handler, current_index, acc) do
    end_index = current_index + 3
    acc = handler.do_true(original, current_index, end_index, acc)
    parse_remaining_whitespace(rest, end_index + 1, original, acc, handler)
  end

  def parse("false" <> rest, original, handler, current_index, acc) do
    end_index = current_index + 4
    acc = handler.do_false(original, current_index, end_index, acc)
    parse_remaining_whitespace(rest, end_index + 1, original, acc, handler)
  end

  # If it's whitespace it should be handled in cases above, so the only option if we get
  # here is if we are seeing an invalid character.
  def parse(<<_byte::binary-size(1), _rest::bits>>, _original, _handler, current_index, _acc) do
    {:error, :invalid_json_character, current_index}
  end

  # We don't check for open array because the caller already did that.
  defp parse_array(array_contents, original, handler, current_index, acc, depth) do
    # current index points to head of array_contents, we want the char before ie the '['
    acc = handler.start_of_array(original, current_index - 1, acc)

    case parse_array_element(array_contents, original, handler, current_index, acc, depth) do
      {:error, _, _} = error -> error
      {end_index, <<>> = rest, acc} -> {end_index - 1, rest, acc}
      {end_index, rest, acc} -> {end_index, rest, acc}
    end
  end

  defp parse_array_element(<<@comma, rest::bits>>, original, handler, comma_index, acc, depth) do
    case skip_whitespace(rest, comma_index + 1) do
      {_end_index, <<@close_array, _::bits>>} -> {:error, :trailing_comma, comma_index}
      {end_index, <<@comma, _::bits>>} -> {:error, :double_comma, end_index}
      {end_index, rest} -> parse_array_element(rest, original, handler, end_index, acc, depth)
    end
  end

  defp parse_array_element(
         <<@close_array, rest::bits>>,
         original,
         handler,
         current_index,
         acc,
         depth
       ) do
    acc = handler.end_of_array(original, current_index, acc)
    new_depth = depth - 1

    if new_depth == 0 do
      {current_index + 1, rest, acc}
    else
      case parse_comma(rest, current_index + 1) do
        {:error, _, _} = error ->
          error

        {end_index, rest} ->
          parse_array_element(rest, original, handler, end_index, acc, new_depth)
      end
    end
  end

  defp parse_array_element(<<@open_array, rest::bits>>, original, handler, index, acc, depth) do
    acc = handler.start_of_array(original, index, acc)
    parse_array_element(rest, original, handler, index + 1, acc, depth + 1)
  end

  defp parse_array_element(
         <<@quotation_mark, rest::bits>>,
         original,
         handler,
         current_index,
         acc,
         depth
       ) do
    case find_string_end(rest, current_index + 1) do
      {:error, :unterminated_string, problematic_char_index} ->
        {:error, :unterminated_string, problematic_char_index}

      # The end index here is the index one BEFORE the closing '"' because we don't send the
      # quotes to the handler. which means we + 1 when calling the end of the document.
      {end_index, ""} ->
        acc = handler.do_string(original, current_index + 1, end_index, acc)

        case parse_comma(rest, end_index) do
          {:error, _, _} = error ->
            error

          {end_index, rest} ->
            parse_array_element(rest, original, handler, end_index + 1, acc, depth)
        end

      {end_index, rest} ->
        acc = handler.do_string(original, current_index + 1, end_index, acc)

        case parse_comma(rest, end_index) do
          {:error, _, _} = error ->
            error

          {end_index, rest} ->
            # Add 1 for the '"' and 1 to be at the char _after_ that.
            parse_array_element(rest, original, handler, end_index + 2, acc, depth)
        end

      {:error, _, _} = error ->
        error
    end
  end

  defp parse_array_element(
         <<head::binary-size(1), rest::binary>>,
         original,
         handler,
         index,
         acc,
         depth
       )
       when head in @whitespace do
    parse_array_element(rest, original, handler, index + 1, acc, depth)
  end

  defp parse_array_element(
         <<byte::binary-size(1), _::bits>> = json,
         original,
         handler,
         current_index,
         acc,
         depth
       )
       when byte in @digits do
    case parse_number(json, current_index) do
      {end_index, rest} ->
        acc = handler.do_positive_number(original, current_index, end_index - 1, acc)

        case parse_comma(rest, end_index) do
          {:error, _, _} = error -> error
          {end_index, rest} -> parse_array_element(rest, original, handler, end_index, acc, depth)
        end

      {:error, _, _} = error ->
        error
    end
  end

  defp parse_array_element(<<@t, rest::bits>>, original, handler, start_index, acc, depth) do
    case parse_true(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_true(original, start_index, end_index - 1, acc)

        case parse_comma(rest, end_index) do
          {:error, _, _} = error -> error
          {end_index, rest} -> parse_array_element(rest, original, handler, end_index, acc, depth)
        end
    end
  end

  defp parse_array_element(<<@f, rest::bits>>, original, handler, start_index, acc, depth) do
    case parse_false(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_false(original, start_index, end_index - 1, acc)

        case parse_comma(rest, end_index) do
          {:error, _, _} = error -> error
          {end_index, rest} -> parse_array_element(rest, original, handler, end_index, acc, depth)
        end
    end
  end

  defp parse_array_element(<<@n, rest::bits>>, original, handler, start_index, acc, depth) do
    case parse_null(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_null(original, start_index, end_index - 1, acc)

        case parse_comma(rest, end_index) do
          {:error, _, _} = error -> error
          {end_index, rest} -> parse_array_element(rest, original, handler, end_index, acc, depth)
        end
    end
  end

  defp parse_array_element(
         <<byte::binary-size(1), _::bits>>,
         _original,
         _handler,
         problematic_char_index,
         _acc,
         _depth
       )
       when byte in @valid_json_chars do
    {:error, :invalid_array_element, problematic_char_index}
  end

  defp parse_array_element(<<>>, _original, _handler, end_index, acc, depth) do
    if depth > 0 do
      {:error, :unclosed_array, end_index - 1}
    else
      {end_index - 1, "", acc}
    end
  end

  defp parse_array_element(_rest, _original, _handler, index, _acc, _depth) do
    {:error, :invalid_json_character, index}
  end

  defp parse_comma(rest, end_index) do
    case skip_whitespace(rest, end_index) do
      {end_index, <<@comma, _rest::bits>> = json} -> {end_index, json}
      {end_index, <<@close_array, _rest::bits>> = json} -> {end_index, json}
      # When is it a missing comma and when is it a missing close array? Visually [[] is
      # the latter, but the first error we see is the missing comma. Is there any way to
      # disambiguate the two?
      {end_index, _rest} -> {:error, :missing_comma, end_index - 1}
    end
  end

  defp parse_true("rue" <> rest, current_index), do: {current_index + 3, rest}
  defp parse_true("ru" <> _, current_index), do: {:error, :invalid_boolean, current_index + 2}
  defp parse_true("r" <> _, current_index), do: {:error, :invalid_boolean, current_index + 1}
  defp parse_true(_, current_index), do: {:error, :invalid_boolean, current_index}

  defp parse_false("alse" <> rest, current_index), do: {current_index + 4, rest}
  defp parse_false("als" <> _, current_index), do: {:error, :invalid_boolean, current_index + 3}
  defp parse_false("al" <> _, current_index), do: {:error, :invalid_boolean, current_index + 2}
  defp parse_false("a" <> _, current_index), do: {:error, :invalid_boolean, current_index + 1}
  defp parse_false(_, current_index), do: {:error, :invalid_boolean, current_index}

  # We already know there is an 'n' because that's how we decided to call this fn. In the
  # happy case we want to point to the last 'l' so we can emit an event with that as the end
  # index. In the error case we want to point to the first erroneous char, which is one after the
  # match. current_index should always point at the head of the binary.

  # This happy return path sort of fucks up the idea that the index should point to the head of
  # "rest". Instead it currently points one back which is an issue. In general we need to align
  # on that and be prepared to subtract 1 when getting the final index.
  defp parse_null("ull" <> rest, current_index), do: {current_index + 3, rest}
  defp parse_null("ul" <> _, current_index), do: {:error, :invalid_boolean, current_index + 2}
  defp parse_null("u" <> _, current_index), do: {:error, :invalid_boolean, current_index + 1}
  defp parse_null(_, current_index), do: {:error, :invalid_boolean, current_index}

  defp skip_whitespace(<<head::binary-size(1), rest::binary>>, index) when head in @whitespace do
    skip_whitespace(rest, index + 1)
  end

  defp skip_whitespace(remaining, index), do: {index, remaining}

  # Is there ever a case where this is wrong? Yes, if there are escaped backslash at the end
  # of the string, no? Test that.
  defp find_string_end(<<@backslash, @quotation_mark, rest::bits>>, end_character_index) do
    find_string_end(rest, end_character_index + 2)
  end

  defp find_string_end(<<@quotation_mark, rest::bits>>, end_character_index) do
    # We skip the start and end quotation mark because it gets captured in the Elixir string
    # That gets created from it.
    {end_character_index - 1, rest}
  end

  defp find_string_end(<<_byte::binary-size(1), rest::bits>>, end_character_index) do
    find_string_end(rest, end_character_index + 1)
  end

  defp find_string_end(<<>>, end_character_index) do
    {:error, :unterminated_string, end_character_index - 1}
  end

  def parse_number(json, index) do
    case parse_digits(json, index) do
      {index, <<@decimal_point, rest::bits>>} -> parse_fractional_digits(rest, index + 1)
      {index, <<byte, rest::bits>>} when byte in 'eE' -> parse_exponent(rest, index + 1)
      {index, rest} -> {index, rest}
    end
  end

  defp parse_digits(<<byte::binary-size(1), rest::bits>>, index) when byte in @all_digits do
    parse_digits(rest, index + 1)
  end

  defp parse_digits(<<>> = rest, index), do: {index - 1, rest}
  defp parse_digits(rest, index), do: {index, rest}

  defp parse_fractional_digits(rest, index) do
    case parse_digits(rest, index) do
      {index, <<e, rest::bits>>} when e in 'eE' -> parse_exponent(rest, index + 1)
      {index, rest} -> {index, rest}
    end
  end

  defp parse_exponent(<<sign, digit, rest::bits>>, index)
       when sign in '+-' and digit in '0123456789' do
    parse_digits(rest, index + 2)
  end

  defp parse_exponent(<<digit, rest::bits>>, index) when digit in '0123456789' do
    parse_digits(rest, index + 1)
  end

  defp parse_exponent(_rest, index) do
    {:error, :invalid_exponent, index}
  end

  # Call this when you are expecting only whitespace to exist. If there is only whitespace
  # we call end_of_document with the correct index, if there is something other than whitespace
  # we return an appropriate error; either multiple bare values or invalid json char.

  # We need to parameterize the termination chars because we want different things at different
  # times. When parsing an array valid termination chars are different from any other time.
  defp parse_remaining_whitespace(
         <<head::binary-size(1), rest::binary>>,
         current_index,
         original,
         acc,
         handler
       )
       when head in @whitespace do
    parse_remaining_whitespace(rest, current_index + 1, original, acc, handler)
  end

  defp parse_remaining_whitespace(<<>>, current_index, original, acc, handler) do
    handler.end_of_document(original, current_index - 1, acc)
  end

  defp parse_remaining_whitespace(
         <<byte::binary-size(1), _rest::bits>>,
         problematic_char_index,
         _original,
         _acc,
         _handler
       )
       when byte in @valid_json_chars do
    {:error, :multiple_bare_values, problematic_char_index}
  end

  defp parse_remaining_whitespace(_rest, current_index, _original, _acc, _handler) do
    {:error, :invalid_json_character, current_index}
  end
end
