defmodule Jxon do
  @moduledoc """
  Documentation for `Jxon`.

  General note, Jason seems to use binary part to extract data from the original binary so
  it's probably faster. But it requires keeping a count for the start/end indexes for the
  things we care about. Do we care enough to do this? Is this production approach or like
  a demo for a presentation. I guess we should do it properly... Though properly feels like
  writing both and then benchmarking each... And it feels like we've already chunked off
  the bits we care about?
  """
  # " "
  @space <<0x20>>
  # \t
  @horizontal_tab <<0x09>>
  # \n
  @new_line <<0x0A>>
  # \r
  @carriage_return <<0x0D>>
  @whitespace [@space, @horizontal_tab, @new_line, @carriage_return]
  @doc """
  The key point with this is that we emit events with the correct data. To test
  that we want to supply a test handler so we can assert that it is called.

  There are simple rules about what we expect after we see specific chars. So it makes
  sense to think about all of the top level "tells" for the type. For JSON I think they
  would be the following:

    [
    "
    {
    0..9 (ie a number)
    - (for a minus number)
    f | t (ie false or true)
    n (ie null)

  From there we can tell which data type we are dealing with, and so can parse up until
  we see the next character that matters for that specific data type.
  """
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
    parse_number(number)
  end

  def parse("null" <> rest, handler, acc) do
    if skip_whitespace(rest) == "" do
      handler.do_null(acc)
    else
      {:error, :multiple_bare_values}
    end
  end

  def parse("true" <> rest, handler, acc) do
    if skip_whitespace(rest) == "" do
      handler.do_true(acc)
    else
      {:error, :multiple_bare_values}
    end
  end

  def parse("false" <> rest, handler, acc) do
    if skip_whitespace(rest) == "" do
      handler.do_false(acc)
    else
      {:error, :multiple_bare_values}
    end
  end

  # if we think we have a number we can consumer characters until we get to terminal character
  # OR until we see something that indicates an error. This is more subtle than it seems
  # because a . is valid, but only once.

  # There may be too many error possibilities here. So.. instead we need to parse numbers
  defp parse_number(<<byte, rest::bits>>) when byte in '0123456789' do
    #
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

  This iterates through the binary one byte at a time which means the terminating char should
  be one byte. If multiple terminating chars are provided we stop as soon as we see any one
  of them.

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
