defmodule Jxon.StringHandler do
  @moduledoc """
  This is just a place to house a half done string handler function that
  does some string escaping. Escaping unicode properly is all that is left, but for the
  purpose of this parser we think the string escaping should be done in handlers.
  later I will move this to be inside a handler, or have it be a helper function that a
  handler could call.

  If we were really doing it properly we might try and see how fast things are when we
  implement string.


  This implies that we should leave that up to the handler though, to enable
  JCS - JSON Canonicalization Scheme ... We could try to validate the unicode and error
  if we see something amiss, but I think it would be better left to the handlers honestly.
  https://www.rfc-editor.org/rfc/rfc8785
  """
  @backslash <<0x5C>>
  @forwardslash <<0x2F>>
  @quotation_mark <<0x22>>
  @u <<0x75>>
  @b <<0x62>>
  @f <<0x66>>
  @n <<0x6E>>
  @r <<0x72>>
  @t <<0x74>>
  @doc """
  A function that turns a JSON string into an Elixir string, doing some escaping along the way.
  """
  def parse_string(<<@backslash, @backslash, rest::bits>>, acc) do
    parse_string(rest, [acc | @backslash])
  end

  def parse_string(<<@backslash, @forwardslash, rest::bits>>, acc) do
    parse_string(rest, [acc | @forwardslash])
  end

  def parse_string(<<@backslash, @b, rest::bits>>, acc) do
    parse_string(rest, [acc | '\b'])
  end

  def parse_string(<<@backslash, @f, rest::bits>>, acc) do
    parse_string(rest, [acc | '\f'])
  end

  def parse_string(<<@backslash, @n, rest::bits>>, acc) do
    parse_string(rest, [acc | '\n'])
  end

  def parse_string(<<@backslash, @r, rest::bits>>, acc) do
    parse_string(rest, [acc | '\r'])
  end

  def parse_string(<<@backslash, @t, rest::bits>>, acc) do
    parse_string(rest, [acc | '\t'])
  end

  def parse_string(<<@backslash, @u, _rest::bits>>, _acc) do
    raise "Unicode escape not implemented yet."
  end

  def parse_string(<<@backslash, @quotation_mark, rest::bits>>, acc) do
    parse_string(rest, [acc | @quotation_mark])
  end

  def parse_string(<<@backslash, _rest::bits>> = string, acc) do
    {:error, :unescaped_backslash, string, acc}
  end

  def parse_string(<<@quotation_mark, rest::bits>>, acc) do
    # We exclude the speech marks that bracket the string because they become the speech
    # marks in the Elixir string.
    {IO.iodata_to_binary(acc), rest}
  end

  def parse_string(<<byte::binary-size(1), rest::bits>>, acc) do
    parse_string(rest, [acc | byte])
  end

  def parse_string(<<>>, acc) do
    {:error, :unterminated_string, IO.iodata_to_binary(acc)}
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
