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

  def parse("true", handler, acc), do: handler.do_true(acc)
  def parse("false", handler, acc), do: handler.do_value(acc)
  def parse("null", handler, acc), do: handler.do_null(acc)

  def parse("-" <> number, handler, acc) do
    # TODO change name as we don't parse it we find the end index of it. very different.
    case parse_integer(number, 0) do
      {end_index, remaining} ->
        number = :binary.part(number, 0, end_index)
        parse(remaining, handler, handler.do_negative_number(number, acc))

      {:error, _, _} = error ->
        error
    end
  end

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

  # This will return the end index of the number as far as we can see it, erroring if we
  # see something we shouldn't along the way (like whitespace or a " or [ etc).

  # Leading zeros are prohibited!!
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON
  # it goes [ minus ] int [frac] [exp]
  # which means we can see frac without exp and exp without frac.
  defp parse_integer(<<?0, rest::bits>>, _number_end_index) do
    # Would it be good for handlers to be able do this optionally? Like as an extension
    # allow leading 0s in integers or something. Seems like that would be good...
    {:error, :leading_zero, <<?0>> <> rest}
  end

  defp parse_integer(<<byte, rest::bits>>, number_end_index) when byte in '123456789' do
    # To reduce the mems we keep a count of how far along we are and later we binary_part
    # the section we care about...
    parse_integer(rest, number_end_index + 1)
  end

  defp parse_integer(<<?e, ?+, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<?E, ?+, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<?E, ?-, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<?e, ?-, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_integer(<<byte, rest::bits>>, number_end_index) when byte in 'eE' do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_integer(<<?., rest::bits>>, number_end_index) do
    parse_fractional_digits(rest, number_end_index + 1)
  end

  # We also need to detect when we see any other valid terminator, then error on
  # everything else...
  defp parse_integer(<<>> = rest, number_end_index) do
    {number_end_index, rest}
  end

  defp parse_integer(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in [@comma, @quotation_mark | @whitespace] do
    {number_end_index, rest}
  end

  defp parse_integer(rest, _number_end_index) do
    {:error, :invalid_number, rest}
  end

  # This is like parse_number but does not allow for '.'
  defp parse_fractional_digits(<<>> = rest, number_end_index) do
    {number_end_index, rest}
  end

  defp parse_fractional_digits(<<byte, rest::bits>>, number_end_index)
       when byte in '0123456789' do
    parse_fractional_digits(rest, number_end_index + 1)
  end

  defp parse_fractional_digits(<<?e, ?+, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<?E, ?+, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<?E, ?-, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<?e, ?-, rest::bits>>, number_end_index) do
    parse_exponent(rest, number_end_index + 2)
  end

  defp parse_fractional_digits(<<byte, rest::bits>>, number_end_index) when byte in 'eE' do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_fractional_digits(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in [@comma, @quotation_mark | @whitespace] do
    {number_end_index, rest}
  end

  defp parse_fractional_digits(rest, _number_end_index) do
    {:error, :invalid_number, rest}
  end

  defp parse_exponent(<<byte, rest::bits>>, number_end_index) when byte in '0123456789' do
    parse_exponent(rest, number_end_index + 1)
  end

  defp parse_exponent(<<byte::binary-size(1), _rest::bits>> = rest, number_end_index)
       when byte in [@comma, @quotation_mark | @whitespace] do
    {number_end_index, rest}
  end

  defp parse_exponent(<<>> = rest, number_end_index) do
    {number_end_index, rest}
  end

  defp parse_exponent(rest, _number_end_index) do
    {:error, :invalid_number, rest}
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
