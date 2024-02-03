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

  @doc """
  """
  def parse(_json) do
    raise "not implemented"
  end

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
