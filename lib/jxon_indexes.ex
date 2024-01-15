defmodule JxonIndexes do
  @moduledoc """
  This version of the parser supplies start and end indexes to each of the callbacks and
  the original binary. That allows callers to implement callbacks that access the parts of
  the binary they care about and choose to copy or reference the original binary.

  This is a currently untested sketch. It's probably off by one in a few places.

  What would be real nice here is a debugger. But failing that an indication of the call path
  a specific test case goes through, ie a stack trace I guess. Being able to know precisely
  which paths are being taken for a given bit of data is game changing and that's all I'm
  trying to replicate with the print debugging.
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
  # @plus <<0x2B>>
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
  @doc """
  """
  def parse(document, handler, current_index, acc) do
    parse(document, document, handler, current_index, acc)
  end

  def parse(<<>>, original, handler, current_index, acc) do
    handler.end_of_document(original, current_index, acc)
  end

  def parse(<<head::binary-size(1), rest::binary>>, original, handler, current_index, acc)
      when head in @whitespace do
    parse(rest, original, handler, current_index + 1, acc)
  end

  def parse(<<@open_object, rest::bits>>, original, handler, current_index, acc) do
    case parse_object(rest, original, handler, current_index + 1, acc, 0, 1) do
      {:error, _, _} = error -> error
      {index, rest, acc} -> parse_remaining_whitespace(rest, index, original, acc, handler)
    end
  end

  def parse(<<@open_array, rest::bits>>, original, handler, current_index, acc) do
    # Last two args are array_depth and object depth
    case parse_array(rest, original, handler, current_index + 1, acc, 1, 0) do
      {:error, _, _} = error -> error
      {index, rest, acc, _, _} -> parse_remaining_whitespace(rest, index, original, acc, handler)
    end
  end

  # Leading zeros are prohibited!!
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON

  # if it's 0 followed by a non digit then it's allowed? If it's followed by a digit it's not
  def parse(
        <<@zero, next::binary-size(1), _rest::bits>>,
        _original,
        _handler,
        current_index,
        _acc
      )
      when next in @all_digits do
    {:error, :leading_zero, current_index}
  end

  def parse(
        <<@minus, @zero, next::binary-size(1), _rest::bits>>,
        _original,
        _handler,
        current_index,
        _acc
      )
      when next in @all_digits do
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
      when digit in @all_digits do
    case parse_number(number, current_index + 2) do
      {end_index, remaining} ->
        acc = handler.do_negative_number(original, current_index, end_index - 1, acc)
        parse_remaining_whitespace(remaining, end_index, original, acc, handler)

      {:error, _, _} = error ->
        error
    end
  end

  def parse(<<byte::binary-size(1), rest::bits>>, original, handler, current_index, acc)
      when byte in @all_digits do
    case parse_number(rest, current_index + 1) do
      {end_index, remaining} ->
        acc = handler.do_positive_number(original, current_index, end_index - 1, acc)
        parse_remaining_whitespace(remaining, end_index, original, acc, handler)

      {:error, _, _} = error ->
        error
    end
  end

  def parse(<<@quotation_mark, rest::bits>>, original, handler, current_index, acc) do
    case parse_string(rest, current_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, ""} ->
        acc = handler.do_string(original, current_index, end_index - 1, acc)
        handler.end_of_document(original, end_index - 1, acc)

      {end_index, remaining} ->
        acc = handler.do_string(original, current_index, end_index - 1, acc)
        parse_remaining_whitespace(remaining, end_index, original, acc, handler)
    end
  end

  def parse(<<@t, rest::bits>>, original, handler, start_index, acc) do
    case parse_true(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_true(original, start_index, end_index - 1, acc)
        parse_remaining_whitespace(rest, end_index, original, acc, handler)
    end
  end

  def parse(<<@f, rest::bits>>, original, handler, start_index, acc) do
    case parse_false(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_true(original, start_index, end_index - 1, acc)
        parse_remaining_whitespace(rest, end_index, original, acc, handler)
    end
  end

  def parse(<<@n, rest::bits>>, original, handler, start_index, acc) do
    case parse_null(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_null(original, start_index, end_index - 1, acc)
        parse_remaining_whitespace(rest, end_index, original, acc, handler)
    end
  end

  # If it's whitespace it should be handled in cases above, so the only option if we get
  # here is if we are seeing an invalid character.
  def parse(<<_byte::binary-size(1), _rest::bits>>, _original, _handler, current_index, _acc) do
    {:error, :invalid_json_character, current_index}
  end

  defp parse_object(rest, original, handler, current_index, acc, array_depth, object_depth) do
    acc = handler.start_of_object(original, current_index - 1, acc)
    ban(rest, original, handler, current_index, acc, array_depth, object_depth)
  end

  defp ban(rest, original, handler, current_index, acc, array_depth, object_depth) do
    case parse_object_key(rest, original, handler, current_index, acc) do
      {:error, _, _} = error ->
        error

      # The problem with the object thing is if you see a comma you need to see a key
      # again, which is unlike the array situation. So to re-use we need to make the
      # parse_array fn call case parse_value when it gets returned a value, unless
      # it's end of the array or document.. It's worth re-use because there would be a lot
      # of duplication

      # Can we get into a situation where we are erroneously closing an object or array before
      # we have opened it?

      {end_index, rest, acc} ->
        # This is the space after the key.
        case skip_whitespace(rest, end_index) do
          {:error, _, _} = error ->
            error

          {index, rest} ->
            # Now then. Some values are not valid here, like a closing array. Will that be
            # captured by depth? YES if we have our checks that depth should never be < 0,
            # but the Q is where to put that...
            case parse_value(rest, original, handler, index, acc, array_depth, object_depth) do
              {:error, _, _} = error ->
                error

              {end_index, rest, acc, 0, 0} ->
                {end_index, rest, acc}

              {end_index, rest, acc, array_depth, object_depth} ->
                case parse_comma(rest, end_index, array_depth, object_depth) do
                  {:error, _, _} = error ->
                    error

                  {end_index, rest} ->
                    parse_values(
                      rest,
                      original,
                      handler,
                      end_index,
                      acc,
                      array_depth,
                      object_depth
                    )
                end
            end
        end
    end
  end

  defp parse_object_key(<<head::binary-size(1), rest::binary>>, original, handler, index, acc)
       when head in @whitespace do
    parse_object_key(rest, original, handler, index + 1, acc)
  end

  # Can't have empty object key.
  defp parse_object_key(<<@quotation_mark, @quotation_mark, _rest::bits>>, _, _, index, _) do
    {:error, :invalid_object_key, index}
  end

  # can there be whitespace between the speech mark and colon? YES!
  defp parse_object_key(<<@quotation_mark, rest::bits>>, original, handler, index, acc) do
    case parse_string(rest, index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.object_key(original, index, end_index - 1, acc)

        case parse_colon(rest, end_index) do
          {:error, _, _} = error -> error
          {end_index, rest} -> {end_index, rest, acc}
        end
    end
  end

  defp parse_object_key(_rest, _original, _handler, index, _acc) do
    {:error, :invalid_object_key, index}
  end

  # We don't check for open array because the caller already did that.
  defp parse_array(
         array_contents,
         original,
         handler,
         current_index,
         acc,
         array_depth,
         object_depth
       ) do
    # current index points to head of array_contents, we want the char before ie the '['
    acc = handler.start_of_array(original, current_index - 1, acc)

    case skip_whitespace(array_contents, current_index) do
      {end_index, <<@comma, _::bits>>} ->
        {:error, :leading_comma, end_index}

      {end_index, rest} ->
        case parse_values(rest, original, handler, end_index, acc, array_depth, object_depth) do
          # Here we want to be like "if we see a comma then recur".
          {:error, _, _} = error ->
            error

          {end_index, <<>>, acc} ->
            {end_index - 1, <<>>, acc, array_depth, object_depth}

          {end_index, rest, acc} ->
            {end_index, rest, acc, array_depth, object_depth}
        end
    end
  end

  defp parse_values(rest, original, handler, index, acc, array_depth, object_depth) do
    case parse_value(rest, original, handler, index, acc, array_depth, object_depth) do
      {:error, _, _} = error ->
        error

      {end_index, rest, acc, 0, 0} ->
        {end_index, rest, acc}

      {end_index, rest, acc, array_depth, object_depth} ->
        case parse_comma(rest, end_index, array_depth, object_depth) do
          {:error, _, _} = error ->
            error

          {end_index, rest} ->
            parse_values(
              rest,
              original,
              handler,
              end_index,
              acc,
              array_depth,
              object_depth
            )
        end
    end
  end

  defp parse_value(
         <<@close_array, rest::bits>>,
         original,
         handler,
         current_index,
         acc,
         array_depth,
         object_depth
       ) do
    new_array_depth = array_depth - 1

    if new_array_depth < 0 do
      {:error, :unopened_array, current_index}
    else
      acc = handler.end_of_array(original, current_index, acc)
      {current_index + 1, rest, acc, new_array_depth, object_depth}
    end
  end

  defp parse_value(
         <<@open_array, rest::bits>>,
         original,
         handler,
         index,
         acc,
         array_depth,
         object_depth
       ) do
    acc = handler.start_of_array(original, index, acc)

    case skip_whitespace(rest, index + 1) do
      {end_index, <<@comma, _::bits>>} ->
        {:error, :leading_comma, end_index}

      {index, rest} ->
        parse_value(rest, original, handler, index, acc, array_depth + 1, object_depth)
    end
  end

  defp parse_value(
         <<@open_object, rest::bits>>,
         original,
         handler,
         index,
         acc,
         array_depth,
         object_depth
       ) do
    parse_object(rest, original, handler, index + 1, acc, array_depth, object_depth + 1)
  end

  # Aha. So we have hit the problem we anticipated. The order in which we see objects / arrays
  # matters. A simple count is not effective enough BECAUSE the counts can be correct but
  # there can be a parse error? EG "{\"b\": { \"a\": [ } } "
  # Perhaps it's as simple as saying that the one which is closing is the greatest of the two?
  # but that can't be correct either. You could have 17 open objects before one array open.

  # The rule is simply; The order in which things open is the order in which they should
  # close. Now that we are talking about order we need to save that order, which means
  # a stack baby.
  defp parse_value(
         <<@close_object, rest::bits>>,
         original,
         handler,
         current_index,
         acc,
         array_depth,
         object_depth
       ) do
    new_object_depth = object_depth - 1
    object_depth |> IO.inspect(limit: :infinity, label: "OBJ depth")
    array_depth |> IO.inspect(limit: :infinity, label: "ARR depth")

    if new_object_depth < 0 do
      {:error, :unopened_object, current_index}
    else
      acc = handler.end_of_object(original, current_index, acc)
      {current_index + 1, rest, acc, array_depth, new_object_depth}
    end
  end

  defp parse_value(
         <<@quotation_mark, rest::bits>>,
         original,
         handler,
         current_index,
         acc,
         array_depth,
         object_depth
       ) do
    case parse_string(rest, current_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_string(original, current_index, end_index - 1, acc)
        {end_index, rest, acc, array_depth, object_depth}
    end
  end

  defp parse_value(
         <<head::binary-size(1), rest::binary>>,
         original,
         handler,
         index,
         acc,
         array_depth,
         object_depth
       )
       when head in @whitespace do
    parse_value(rest, original, handler, index + 1, acc, array_depth, object_depth)
  end

  defp parse_value(<<@zero, next::binary-size(1), _::bits>>, _, _, current_index, _, _, _)
       when next in @all_digits do
    {:error, :leading_zero, current_index}
  end

  defp parse_value(
         <<@minus, @zero, next::binary-size(1), _rest::bits>>,
         _original,
         _handler,
         current_index,
         _acc,
         _array_depth,
         _object_depth
       )
       when next in @all_digits do
    # This points to the 0 and not the '-'
    {:error, :leading_zero, current_index + 1}
  end

  defp parse_value(
         <<@minus, digit::binary-size(1), number::bits>>,
         original,
         handler,
         current_index,
         acc,
         array_depth,
         object_depth
       )
       when digit in @all_digits do
    case parse_number(number, current_index + 2) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_negative_number(original, current_index, end_index - 1, acc)
        {end_index, rest, acc, array_depth, object_depth}
    end
  end

  defp parse_value(
         <<byte::binary-size(1), _::bits>> = json,
         original,
         handler,
         current_index,
         acc,
         array_depth,
         object_depth
       )
       when byte in @all_digits do
    case parse_number(json, current_index) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        # we subtract 1 because we are only sure we have finished parsing the number once
        # we have stepped past it. So end_index points to one char after the end of the number.
        acc = handler.do_positive_number(original, current_index, end_index - 1, acc)
        {end_index, rest, acc, array_depth, object_depth}
    end
  end

  defp parse_value(
         <<@t, rest::bits>>,
         original,
         handler,
         start_index,
         acc,
         array_depth,
         object_depth
       ) do
    case parse_true(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_true(original, start_index, end_index - 1, acc)
        {end_index, rest, acc, array_depth, object_depth}
    end
  end

  defp parse_value(
         <<@f, rest::bits>>,
         original,
         handler,
         start_index,
         acc,
         array_depth,
         object_depth
       ) do
    case parse_false(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_false(original, start_index, end_index - 1, acc)
        {end_index, rest, acc, array_depth, object_depth}
    end
  end

  defp parse_value(
         <<@n, rest::bits>>,
         original,
         handler,
         start_index,
         acc,
         array_depth,
         object_depth
       ) do
    case parse_null(rest, start_index + 1) do
      {:error, _, _} = error ->
        error

      {end_index, rest} ->
        acc = handler.do_null(original, start_index, end_index - 1, acc)
        {end_index, rest, acc, array_depth, object_depth}
    end
  end

  defp parse_value(<<>>, _original, _handler, end_index, acc, 0, 0) do
    {end_index - 1, "", acc, 0, 0}
  end

  defp parse_value(<<>>, _original, _handler, end_index, _acc, array_depth, object_depth) do
    if array_depth > object_depth do
      {:error, :unclosed_array, end_index - 1}
    else
      if object_depth > array_depth do
        {:error, :unclosed_object, end_index - 1}
      else
        {:error, :unclosed_collections, end_index - 1}
      end
    end
  end

  defp parse_value(
         <<byte::binary-size(1), _::bits>>,
         _original,
         _handler,
         problematic_char_index,
         _acc,
         _array_depth,
         _object_depth
       )
       when byte in @value_indicators do
    {:error, :multiple_bare_values, problematic_char_index}
  end

  defp parse_value(_rest, _original, _handler, index, _acc, _array_depth, _object_depth) do
    {:error, :invalid_json_character, index}
  end

  defp parse_colon(rest, index) do
    case skip_whitespace(rest, index) do
      {end_index, <<@colon, rest::bits>>} -> {end_index + 1, rest}
      # This will be if we see a colon and then nothing after it.
      {end_index, ""} -> {:error, :missing_object_value, end_index - 1}
      {end_index, _rest} -> {:error, :missing_key_value_separator, end_index}
    end
  end

  defp parse_comma(rest, index, array_depth, object_depth) do
    case skip_whitespace(rest, index) do
      {comma_index, <<@comma, rest::bits>>} ->
        case skip_whitespace(rest, comma_index + 1) do
          {end_index, <<@comma, _rest::bits>>} ->
            {:error, :double_comma, end_index}

          {_end_index, <<@close_array, _rest::bits>>} ->
            {:error, :trailing_comma, comma_index}

          {_end_index, <<@close_object, _rest::bits>>} ->
            {:error, :trailing_comma, comma_index}

          {end_index, ""} ->
            if array_depth > object_depth do
              {:error, :unclosed_array, end_index - 1}
            else
              if object_depth > array_depth do
                {:error, :unclosed_object, end_index - 1}
              else
                # here it depends on what the last collection token we saw was? Can we know
                # that ever? The handler would. In truth though both are unclosed...
                # consider [ {  vs { [. We'd like to say object in the former but array in the latter.
                # We could actually do that if we use a stack where the head is the latest opened collection.
                # the values in the stack is always the depth count? Ooo that could be clever.
                # I think the problem is the stack has to be one for every collection you see
                # because the order can change a lot... And I was trying to avoid having stacks like
                # that for the mems implications? What you can do is compress it using the technique
                # from before: If there are two open arrays in a row just increment. Then if it's
                # as you close you either remove or decrement. That's the best we could do.

                # TODO: Come back and do that because that is very cool?
                {:error, :unclosed_collections, end_index - 1}
              end
            end

          {end_index, rest} ->
            {end_index, rest}
        end

      {end_index, ""} ->
        if array_depth > object_depth do
          {:error, :unclosed_array, end_index - 1}
        else
          if object_depth > array_depth do
            {:error, :unclosed_object, end_index - 1}
          else
            {:error, :unclosed_collections, end_index - 1}
          end
        end

      {end_index, <<@close_array, _rest::bits>> = json} ->
        {end_index, json}

      {end_index, <<@close_object, _rest::bits>> = json} ->
        {end_index, json}

      {end_index, <<byte::binary-size(1), _rest::bits>>} when byte in @value_indicators ->
        {:error, :multiple_bare_values, end_index}

      {end_index, _rest} ->
        {:error, :invalid_json_character, end_index}
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
  # happy case we want to point to the last 'l' + 1 so that we maintain the invariant that
  # the index always points to the head of rest. It means on success we want to - 1 to get
  # the end of the value. But that's fine.

  # In the error case we want to point to the first erroneous char, which is one after the
  # match.
  defp parse_null("ull" <> rest, current_index), do: {current_index + 3, rest}
  defp parse_null("ul" <> _, current_index), do: {:error, :invalid_boolean, current_index + 2}
  defp parse_null("u" <> _, current_index), do: {:error, :invalid_boolean, current_index + 1}
  defp parse_null(_, current_index), do: {:error, :invalid_boolean, current_index}

  defp skip_whitespace(<<head::binary-size(1), rest::binary>>, index) when head in @whitespace do
    skip_whitespace(rest, index + 1)
  end

  defp skip_whitespace(remaining, index), do: {index, remaining}

  defp parse_string(<<@backslash, @quotation_mark, rest::bits>>, end_character_index) do
    parse_string(rest, end_character_index + 2)
  end

  defp parse_string(<<@quotation_mark, rest::bits>>, end_character_index) do
    # This means we keep the invariant that index points to the head of rest. But means
    # (because we are not emitting here) that we have to - 1 from the index when we emit in
    # the caller. I think other parsers emit here, eg the numbers or arrays. We should make
    # them all the same at some point.
    {end_character_index + 1, rest}
  end

  defp parse_string(<<_byte::binary-size(1), rest::bits>>, end_character_index) do
    parse_string(rest, end_character_index + 1)
  end

  defp parse_string(<<>>, end_character_index) do
    {:error, :unterminated_string, end_character_index - 1}
  end

  def parse_number(json, index) do
    case parse_digits(json, index) do
      {index, <<@decimal_point, byte::binary-size(1), rest::bits>>} when byte in @all_digits ->
        parse_fractional_digits(rest, index + 2)

      {index, <<@decimal_point, _rest::bits>>} ->
        {:error, :invalid_decimal_number, index + 1}

      {index, <<byte, rest::bits>>} when byte in 'eE' ->
        parse_exponent(rest, index + 1)

      {index, rest} ->
        {index, rest}
    end
  end

  defp parse_digits(<<byte::binary-size(1), rest::bits>>, index) when byte in @all_digits do
    parse_digits(rest, index + 1)
  end

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
       when byte in @value_indicators do
    {:error, :multiple_bare_values, problematic_char_index}
  end

  defp parse_remaining_whitespace(_rest, current_index, _original, _acc, _handler) do
    {:error, :invalid_json_character, current_index}
  end
end
