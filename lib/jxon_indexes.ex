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
                      @close_array,
                      @open_object,
                      @close_object,
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

  # Leading zeros are prohibited!!
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON
  def parse(<<@zero, _rest::bits>>, _original, _handler, current_index, acc) do
    # Would it be good for handlers to be able do this optionally? Like as an extension
    # allow leading 0s in integers or something. Seems like that would be good... To do
    # that we could call the handler and then case on the return value to decide wither we
    # continue or not. In reality we could do that anyway everywhere we call the handler and
    # have a haltable / continueable json parser. We will circle back to this.
    {:error, :leading_zero, current_index}
  end

  def parse(<<@minus, @zero, _rest::bits>>, _original, _handler, current_index, acc) do
    # This points to the 0 and not the '-'
    {:error, :leading_zero, current_index + 1}
  end

  def parse(<<@minus, number::bits>>, original, handler, current_index, acc) do
    # We add 1 because we drop the '-' which is what current_index points to.
    case parse_integer(number, current_index + 1) do
      {end_index, ""} ->
        acc = handler.do_negative_number(original, current_index, end_index, acc)
        handler.end_of_document(original, end_index, acc)

      {end_index, remaining} ->
        acc = handler.do_negative_number(original, current_index, end_index, acc)
        parse_remaining_whitespace(remaining, end_index + 1, original, acc, handler)

      {:error, :invalid_fractional_digit, problematic_char_index} ->
        {:error, :invalid_fractional_digit, problematic_char_index}

      {:error, :invalid_exponent, problematic_char_index} ->
        {:error, :invalid_exponent, problematic_char_index}

      {:error, :invalid_integer, problematic_char_index} ->
        {:error, :invalid_integer, problematic_char_index}
    end
  end

  def parse(<<byte::binary-size(1), rest::bits>> = current, original, handler, current_index, acc)
      when byte in @digits do
    case parse_integer(current, current_index) do
      {end_index, ""} ->
        acc = handler.do_positive_number(original, current_index, end_index, acc)
        handler.end_of_document(original, end_index, acc)

      {end_index, remaining} ->
        acc = handler.do_positive_number(original, current_index, end_index, acc)
        parse_remaining_whitespace(remaining, end_index + 1, original, acc, handler)

      {:error, :invalid_fractional_digit, problematic_char_index} ->
        {:error, :invalid_fractional_digit, problematic_char_index}

      {:error, :invalid_exponent, problematic_char_index} ->
        {:error, :invalid_exponent, problematic_char_index}

      {:error, :invalid_integer, problematic_char_index} ->
        {:error, :invalid_integer, problematic_char_index}
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
  def parse(<<byte::binary-size(1), _rest::bits>>, _original, _handler, current_index, acc) do
    {:error, :invalid_json_character, current_index}
  end

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

  defp find_string_end(<<byte::binary-size(1), rest::bits>>, end_character_index) do
    find_string_end(rest, end_character_index + 1)
  end

  defp find_string_end(<<>>, end_character_index) do
    {:error, :unterminated_string, end_character_index - 1}
  end

  # it goes [ minus ] int [frac] [exp] which means we can see frac without exp and exp without frac.
  defp parse_integer(<<byte::binary-size(1), rest::bits>>, number_end_index)
       when byte in [@zero | @digits] do
    parse_integer(rest, number_end_index + 1)
  end

  defp parse_integer(<<?e, @plus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<?E, @plus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<?E, @minus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<?e, @minus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<byte, rest::bits>>, number_end_index) when byte in 'eE' do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_integer(<<@decimal_point, rest::bits>>, number_end_index) do
    parse_fractional_digits(rest, number_end_index + 1)
  end

  defp parse_integer(<<>> = rest, number_end_index) do
    {number_end_index - 1, rest}
  end

  defp parse_integer(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in @whitespace do
    {number_end_index - 1, rest}
  end

  defp parse_integer(_rest, number_end_index) do
    {:error, :invalid_integer, number_end_index}
  end

  # This is like parse_number but does not allow for '.'
  defp parse_fractional_digits(<<>> = rest, number_end_index) do
    {number_end_index - 1, rest}
  end

  defp parse_fractional_digits(<<byte::binary-size(1), rest::bits>>, number_end_index)
       when byte in [@zero | @digits] do
    parse_fractional_digits(rest, number_end_index + 1)
  end

  defp parse_fractional_digits(<<?e, @plus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<?E, @plus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<?E, @minus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<?e, @minus, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<byte, rest::bits>>, number_end_index) when byte in 'eE' do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_fractional_digits(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in @whitespace do
    # we hit a space so we actually want to end on the char before this one.
    {number_end_index - 1, rest}
  end

  defp parse_fractional_digits(_rest, number_end_index) do
    {:error, :invalid_fractional_digit, number_end_index}
  end

  defp parse_exponent(<<byte::binary-size(1), rest::bits>>, number_end_index)
       when byte in [@zero | @digits] do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_exponent(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in @whitespace do
    # we hit a space so we actually want to end on the char before this one.
    {number_end_index - 1, rest}
  end

  defp parse_exponent(<<>> = rest, number_end_index) do
    {number_end_index - 1, rest}
  end

  defp parse_exponent(_rest, number_end_index) do
    {:error, :invalid_exponent, number_end_index}
  end

  # Call this when you are expecting only whitespace to exist. If there is only whitespace
  # we call end_of_document with the correct index, if there is something other than whitespace
  # we return an appropriate error; either multiple bare values or invalid json char.
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

  defp parse_remaining_whitespace(remaining, current_index, _original, _acc, _handler) do
    {:error, :invalid_json_character, current_index}
  end
end
