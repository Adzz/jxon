defmodule Jxon do
  @moduledoc """
  An event based JSON parser.

  https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON

      JSON-text = object / array
      begin-array     = ws %x5B ws  ; [ left square bracket
      begin-object    = ws %x7B ws  ; { left curly bracket
      end-array       = ws %x5D ws  ; ] right square bracket
      end-object      = ws %x7D ws  ; } right curly bracket
      name-separator  = ws %x3A ws  ; : colon
      value-separator = ws %x2C ws  ; , comma
      ws = *(
           %x20 /              ; Space
           %x09 /              ; Horizontal tab
           %x0A /              ; Line feed or New line
           %x0D                ; Carriage return
           )
      value = false / null / true / object / array / number / string
      false = %x66.61.6c.73.65   ; false
      null  = %x6e.75.6c.6c      ; null
      true  = %x74.72.75.65      ; true
      object = begin-object [ member *( value-separator member ) ]
               end-object
      member = string name-separator value
      array = begin-array [ value *( value-separator value ) ] end-array
      number = [ minus ] int [ frac ] [ exp ]
      decimal-point = %x2E       ; .
      digit1-9 = %x31-39         ; 1-9
      e = %x65 / %x45            ; e E
      exp = e [ minus / plus ] 1*DIGIT
      frac = decimal-point 1*DIGIT
      int = zero / ( digit1-9 *DIGIT )
      minus = %x2D               ; -
      plus = %x2B                ; +
      zero = %x30                ; 0
      string = quotation-mark *char quotation-mark
      char = unescaped /
          escape (
              %x22 /          ; "    quotation mark  U+0022
              %x5C /          ; \    reverse solidus U+005C
              %x2F /          ; /    solidus         U+002F
              %x62 /          ; b    backspace       U+0008
              %x66 /          ; f    form feed       U+000C
              %x6E /          ; n    line feed       U+000A
              %x72 /          ; r    carriage return U+000D
              %x74 /          ; t    tab             U+0009
              %x75 4HEXDIG )  ; uXXXX                U+XXXX
      escape = %x5C              ; \
      quotation-mark = %x22      ; "
      unescaped = %x20-21 / %x23-5B / %x5D-10FFFF
      HEXDIG = DIGIT / %x41-46 / %x61-66   ; 0-9, A-F, or a-f
             ; HEXDIG equivalent to HEXDIG rule in [RFC5234]
      DIGIT = %x30-39            ; 0-9
            ; DIGIT equivalent to DIGIT rule in [RFC5234]
  """
  # " "
  @space <<0x20>>
  # \t
  @horizontal_tab <<0x09>>
  # \n
  @new_line <<0x0A>>
  # \r
  @carriage_return <<0x0D>>
  # Does this go in white space?
  # @form_feed <<0x66>>
  @whitespace [@space, @horizontal_tab, @new_line, @carriage_return]
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
  @doc """
  """
  def parse(<<>>, handler, acc), do: handler.end_of_document(acc)
  def parse(@space <> rest, handler, acc), do: parse(rest, handler, acc)
  def parse(@horizontal_tab <> rest, handler, acc), do: parse(rest, handler, acc)
  def parse(@new_line <> rest, handler, acc), do: parse(rest, handler, acc)
  def parse(@carriage_return <> rest, handler, acc), do: parse(rest, handler, acc)

  # would it be better to do this? Faster? slower? clearer? no different?
  # I'm hoping the above re-uses the match context or whatever.
  # def parse(string) do
  #   parse(skip_whitespace(string))
  # end

  # Leading zeros are prohibited!!
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON
  def parse(<<@zero, rest::bits>>, _handler, _acc) do
    # Would it be good for handlers to be able do this optionally? Like as an extension
    # allow leading 0s in integers or something. Seems like that would be good... To do
    # that we could call the handler and then case on the return value to decide wither we
    # continue or not. In reality we could do that anyway everywhere we call the handler and
    # have a haltable / continueable json parser. We will circle back to this.
    {:error, :leading_zero, @zero <> rest}
  end

  def parse(<<@minus, @zero, rest::bits>>, _handler, _acc) do
    {:error, :leading_zero, @zero <> rest}
  end

  def parse(<<@minus, number::bits>> = original, handler, acc) do
    case parse_integer(number, 0) do
      {end_index, remaining} ->
        if skip_whitespace(remaining) == "" do
          number = :binary.part(number, 0, end_index)
          handler.do_negative_number(number, acc)
        else
          {:error, :multiple_bare_values, original}
        end

      {:error, :invalid_number, _problematic_char_index} ->
        {:error, :invalid_number, original}
    end
  end

  def parse(<<byte::binary-size(1), rest::bits>> = original, handler, acc) when byte in @digits do
    # TODO change name as we don't parse it we find the end index of it. very different.
    case parse_integer(rest, 1) do
      {end_index, remaining} ->
        if skip_whitespace(remaining) == "" do
          number = :binary.part(original, 0, end_index)
          handler.do_positive_number(number, acc)
        else
          {:error, :multiple_bare_values, original}
        end

      {:error, :invalid_number, _problematic_char_index} ->
        # We could call the handler and have it decide what to do here. Alternatively if
        # we provide the problematic_char_index then the caller could snip that char out
        # and attempt a re-parse and stuff. So we should at least provide that I think.
        {:error, :invalid_number, original}
    end
  end

  # I think we need to detect an escaped string too? And allow that?
  # Escaped means we act as if the thing escaped is a literal. But what about this case:
  # json_string = "\"[1, 2, 3, 4]\"" The escaped strings are escaped for the Elixir string
  # but we want them to be actual quote marks to JSON ...

  def parse(<<@quotation_mark, rest::bits>> = original, handler, acc) do
    # Here's the thing, we can't just parse until the next quotation mark because there
    # could be escaped speech marks along the way... To do that we just need to inc/dec
    # the number of escaped " we see. I guess we could parse until we see a ", see if the
    # previous value was a \ and if it is continue. If not, halt as we found the end of
    # our string...?

    # The rules are we can parse a bare string, in which case there should be nothing but
    # white space after it. If we are later in the context of an array or object, that type
    # dictates what can come next... I think. Basically `parse` atm is more like parse_value

    {end_index, remaining} = parse_string(rest, 0, [])

    if skip_whitespace(remaining) == "" do
      string = :binary.part(rest, 0, end_index)
      handler.do_string(string, acc)
    else
      {:error, :multiple_bare_values, original}
    end
  end

  def parse("true", handler, acc), do: handler.do_true(acc)
  def parse("false", handler, acc), do: handler.do_value(acc)
  def parse("null", handler, acc), do: handler.do_null(acc)

  def parse("null" <> rest, handler, acc) do
    if skip_whitespace(rest) == "" do
      handler.do_null(acc)
    else
      {:error, :multiple_bare_values, rest}
    end
  end

  def parse("true" <> rest, handler, acc) do
    if skip_whitespace(rest) == "" do
      handler.do_true(acc)
    else
      {:error, :multiple_bare_values, rest}
    end
  end

  def parse("false" <> rest, handler, acc) do
    if skip_whitespace(rest) == "" do
      handler.do_false(acc)
    else
      {:error, :multiple_bare_values, rest}
    end
  end

  def parse(<<byte::binary-size(1), rest::bits>>, _handler, _acc) do
    byte |> IO.inspect(limit: :infinity, label: "BYTE1")
    raise "Error"
  end

  defp parse_string(<<@backslash, @backslash, rest::bits>>, last_character_index) do

  end

  # It's very possible that this doesn't work? Because do we have to drop the backslash
  # and just have the quotation mark in there as a literal. I think so. Which makes it all
  # a bit more complex because we have to ACCUMULATE which we have managed to avoid up until
  # now. NOW, we could just let the handler deal with that? do the escaping of strings?
  # That would make this quick and enable the option to
  defp parse_string(<<@backslash, @quotation_mark, rest::bits>>, last_character_index) do
    # @backslash |> IO.inspect(limit: :infinity, label: "BYTE2")
    # @quotation_mark |> IO.inspect(limit: :infinity, label: "BYTE2")
    # rest |> IO.inspect(limit: :infinity, label: "rest2")
    parse_string(rest, last_character_index + 2)
  end

  defp parse_string(<<@quotation_mark, rest::bits>>, last_character_index) do
    # rest |> IO.inspect(limit: :infinity, label: "rest3")
    # We exclude the speech marks that bracket the string because they become the speech
    # marks in the Elixir string.
    {last_character_index, rest}
  end

  defp parse_string(<<byte, rest::bits>>, last_character_index) do
    # rest |> IO.inspect(limit: :infinity, label: "rest4")
    parse_string(rest, last_character_index + 1)
  end

  # This will return the end index of the number as far as we can see it, erroring if we
  # see something we shouldn't along the way (like whitespace or a " or [ etc).

  # it goes [ minus ] int [frac] [exp]
  # which means we can see frac without exp and exp without frac.
  defp parse_integer(<<byte::binary-size(1), rest::bits>>, number_end_index)
       when byte in [@zero | @digits] do
    # To reduce the mems we keep a count of how far along we are and later we binary_part
    # the section we care about...
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
    {number_end_index, rest}
  end

  defp parse_integer(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in [@comma, @quotation_mark | @whitespace] do
    {number_end_index, rest}
  end

  defp parse_integer(_rest, number_end_index) do
    {:error, :invalid_number, number_end_index + 1}
  end

  # This is like parse_number but does not allow for '.'
  defp parse_fractional_digits(<<>> = rest, number_end_index) do
    {number_end_index, rest}
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
       when byte in [@comma, @quotation_mark | @whitespace] do
    {number_end_index, rest}
  end

  defp parse_fractional_digits(_rest, number_end_index) do
    {:error, :invalid_number, number_end_index + 1}
  end

  defp parse_exponent(<<byte::binary-size(1), rest::bits>>, number_end_index)
       when byte in [@zero | @digits] do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_exponent(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in [@comma, @quotation_mark | @whitespace] do
    {number_end_index, rest}
  end

  defp parse_exponent(<<>> = rest, number_end_index) do
    {number_end_index, rest}
  end

  defp parse_exponent(_rest, number_end_index) do
    {:error, :invalid_number, number_end_index + 1}
  end

  # Is this faster? Well this stops as soon as you find a non whitespace char, but doesn't
  # actually parse the rest of the binary. That is going to be faster for certain kinds of
  # data. This might also let us return better errors because we wont return an error for
  # some nested data or whatever.
  defp skip_whitespace(<<head::binary-size(1), rest::binary>>) when head in @whitespace do
    skip_whitespace(rest)
  end

  defp skip_whitespace(remaining), do: remaining

  @doc """
  Splits a binary into everything up to the a terminating character, the terminating
  character and everything after that.

  This iterates through the binary one byte at a time which means the terminating char
  should be one byte. If multiple terminating chars are provided we stop as soon as we
  see any one of them.

  It's faster to keep this in this module as the match context gets re-used if we do.
  you can see the warnings if you play around with this:

     ERL_COMPILER_OPTIONS=bin_opt_info mix compile --force
  """
  # could we inline this? Would that be better?
  def parse_until(<<>>, _terminal_char, _acc), do: :terminal_char_never_reached

  def parse_until(<<head::binary-size(1), rest::binary>>, [_ | _] = terminal_chars, acc) do
    if head in terminal_chars do
      {head, acc, rest}
    else
      parse_until(rest, terminal_chars, acc <> head)
    end
  end

  def parse_until(<<head::binary-size(1), rest::binary>>, terminal_char, acc) do
    case head do
      ^terminal_char -> {head, acc, rest}
      char -> parse_until(rest, terminal_char, acc <> char)
    end
  end
end
