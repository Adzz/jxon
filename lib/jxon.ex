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

  def parse(json) do
    instructions = JxonSlim.parse(json, SlimerHandler, 0, [])

    # TODO : start again coz this is trash. Just do a stack and collapse shit like in
    # the Sax handlers.. Not hard.
    # ALso. Don't do this at all. We have to get to passing the schemas into the handler
    # next.
    # Basically we should try pushing around the original binary everywhere to comapre as
    # it looks like that's what Jason does anyway.
    execute_instructions(instructions, json)
  end

  # The options are:
  # 1. Have a data accessor that acts on this stream of instructions.
  # - What is a good data structure for that? Likely a list is not? I suppose you always
  #   need to iterate over the list anyway. We would have to track depth as we navigated
  #   it most likely?
  # 2. Just write a Fn that makes a call on what to do with the type for now
  # - this requires splitting ints and floats though.
  # 3. Ignore these, make a version that passes original around and then benchmark that.
  # 4.

  # First we see what the first instruction is. If it is a value, we just return that and
  # we are done. If it is an object or an array then we have to accumulate!
  # BUT the instruction stream (for now) is in reverse. I think that will be fine because
  # we are going to accumulate by prepending into the list (for example). Also we can be sure
  # that if we are here we are seeing valid JSON.
  defp execute_instructions([:array_end | rest], json) do
    accumulate_list(rest, json, [[]])
  end

  defp execute_instructions([:object_end | rest], json) do
    accumulate_object(rest, json, [:object_start])
  end

  # Perhaps here is where we would do the string escaping if we wanted it....
  defp execute_instructions([{:string, start, len}], json) do
    :binary.part(json, start, len)
  end

  defp execute_instructions([{:positive_number, start, len}], json) do
    :binary.part(json, start, len)
  end

  defp execute_instructions([{:negative_number, start, len}], json) do
    :binary.part(json, start, len)
  end

  # If it is false, true or nil it will already be that value in Elixir, You could choose
  # to do something else like a 1 or 0 or whatever but we don't.
  defp execute_instructions([value], _json) do
    value
  end

  # # Does Acc always need to be a stack? I guess so?
  defp accumulate_list([{instruction, start, len} | rest], json, stack)
       when instruction in [:negative_number, :positive_number] do
    numb = :binary.part(json, start, len)
    decimal = Decimal.new(numb)
    accumulate_list(rest, json, [decimal | stack])
  end

  defp accumulate_list([{:string, start, len} | rest], json, stack) do
    string = :binary.part(json, start, len)
    accumulate_list(rest, json, [string | stack])
  end

  defp accumulate_list([val | rest], json, [head | stack_rest])
       when is_list(head) and val in [true, false, nil] do
    accumulate_list(rest, json, [[val | head] | stack_rest])
  end

  # Object end is starting a new one. We should never see object_start (then end of an obj)
  # because accumulate_object will handle that.
  defp accumulate_list([:object_end | rest], json, [head | stack_rest]) when is_list(head) do
    accumulate_object(rest, json, [:object_start])
    # accumulate_list(rest, json, [[object | head] | stack_rest])
  end

  # Ending an array is starting a new one.
  defp accumulate_list([:array_end | rest], json, stack) do
    accumulate_list(rest, json, [[] | stack])
  end

  # This is the end of the array (because instructions are in reverse order).
  defp accumulate_list([:array_start | rest], json, [head, prev | rest_stack]) do
    accumulate_list(rest, json, [[head | prev] | rest_stack])
  end

  defp accumulate_list([:array_start | rest], json, [head]) do
    head
  end

  # EXAMPLE
  # [
  #   {:object_end, 27, 1},
  #   {:positive_number, 25, 1},
  #   {:object_key, 21, 1},
  #   {:array_end, 17, 1},
  #   {:object_end, 16, 1},
  #   {:positive_number, 15, 1}, 2
  #   {:object_key, 11, 1}, "B"
  #   {:object_start, 8, 1},
  #   {:array_start, 7, 1},
  #   {:object_key, 3, 1},
  #   {:object_start, 0, 1}
  # ]

  # Keys are always followed by values. But we are working with a reversed object stream
  # so we see the values first.
  defp accumulate_object([], json, stack) do
    stack
  end

  defp accumulate_object([{:positive_number, start, len} | rest], json, stack) do
    numb = :binary.part(json, start, len)
    decimal = Decimal.new(numb)
    accumulate_object(rest, json, [{nil, decimal} | stack])
  end

  defp accumulate_object([{:negative_number, start, len} | rest], json, stack) do
    numb = :binary.part(json, start, len)
    decimal = Decimal.new(numb)
    accumulate_object(rest, json, [{nil, decimal} | stack])
  end

  defp accumulate_object([{:string, start, len} | rest], json, stack) do
    string = :binary.part(json, start, len)
    accumulate_object(rest, json, [{nil, string} | stack])
  end

  defp accumulate_object([val | rest], json, stack) when val in [true, nil, false] do
    accumulate_object(rest, json, [{nil, val} | stack])
  end

  # This is the END of the object.
  defp accumulate_object([:object_start | rest], json, [{key, value}]) do
    %{key => value}
  end

  defp accumulate_object([:object_start | rest], json, stack) do
    # now we want to consume rest until we see the empty map that we insert when we start
    # an obj because we are done with it.
    acc = collapse_object(stack, %{})
    accumulate_object(rest, json, acc)
  end

  defp accumulate_object([{:object_key, start, len} | rest], json, stack) do
    key = :binary.part(json, start, len)

    case stack do
      [{nil, value} | rest_of_acc] -> accumulate_object(rest, json, [{key, value} | rest_of_acc])
      [%{} = map | rest_of_acc] -> accumulate_object(rest, json, [{key, map} | rest_of_acc])
    end
  end

  # This is the START of an object
  defp accumulate_object([:object_end | rest], json, stack) do
    accumulate_object(rest, json, [[:object_start] | stack])
  end

  # Array end is actually the start of an array
  defp accumulate_object([:array_end | rest], json, stack) do
    accumulate_list(rest, json, [[]])
  end

  # This is the end of an array...
  defp accumulate_object([:array_start | rest], json, stack) do
    accumulate_object(rest, json, stack)
  end

  # This first arg is not the instructions, it's the stack really.
  defp collapse_object([:object_start | rest], acc) do
    [acc | rest]
  end

  defp collapse_object([{key, value} | rest], acc) do
    collapse_object(rest, Map.put(acc, key, value))
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
