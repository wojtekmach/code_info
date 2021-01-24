defmodule CodeInfo.SpecAST do
  @moduledoc false

  @doc ~S"""
  Converts AST into string.

  `format_fun`, if non-nil, allows formatting types. It can receive one of the
  following:

    * `{:type, name, arity}`

    * `{:user_type, name, arity}`

    * `{:remote_type, module, name, arity}`

  and must return a string rendering that type.

  This is useful to autolink types:

      format_fun = fn
        {:remote_type, module, name, arity} ->
          url = "#{inspect(module)}.html##{name}/#{arity}"
          text = "#{inspect(module)}.#{name}"
          ~s|<a href="#{href}">#{text}</a>|

        ...
      end

  """
  # Notes:
  #
  # We traverse the AST collecting identifiers (types and vars),
  # we replace every one of them with a placeholder that has the
  # same length.
  #
  # For example:
  #
  #   t(a) :: Keyword.t(a) | atom()
  #
  # becomes:
  #
  #   _(_) :: _________(_) | ____()
  #
  # but importantly we have collected the identifiers in order:
  #
  #   t, a, Keyword.t, a, atom
  #
  # Afterwards, we simply convert the placeholders back and pop
  # from our collected identifiers. Variables stay as is but
  # for types, we call the format_fun.
  def to_string(ast, format_fun, formatter_options \\ [])

  def to_string(ast, nil, formatter_options) do
    ast
    |> Macro.to_string()
    |> Code.format_string!(formatter_options)
    |> IO.iodata_to_binary()
  end

  def to_string(ast, format_fun, formatter_options) do
    {ast, acc} = f(ast)

    string =
      ast
      |> Macro.to_string()
      |> Code.format_string!(formatter_options)
      |> IO.iodata_to_binary()

    init!(acc)

    Regex.replace(~r/_+/, string, fn _placeholder ->
      case pop!() do
        {:same, name} ->
          "#{name}"

        other ->
          format_fun.(other)
      end
    end)
  end

  @id {__MODULE__, :placeholders}

  defp init!(items) do
    Process.put(@id, items)
  end

  defp pop!() do
    [head | tail] = Process.get(@id)
    Process.put(@id, tail)
    head
  end

  defp f(ast) do
    {ast, acc} = f(ast, [])
    acc = Enum.reverse(acc)
    dont_process_fun_name(ast, acc)
  end

  defp dont_process_fun_name(ast, acc) do
    [head | tail] = acc

    case head do
      # this is e.g. `f` in `f(a) :: a`,
      # mark it as same (no processing)
      {:user_type, name, _arity} ->
        {ast, [{:same, name} | tail]}

      # this is e.g. `+` in `a + b :: a`,
      # skip it altogether
      {:operator, _} ->
        {ast, tail}
    end
  end

  defp f(quoted, acc) do
    Macro.prewalk(quoted, acc, fn
      {:"::", _, _} = ast, acc ->
        {ast, acc}

      {:|, _, _} = ast, acc ->
        {ast, acc}

      {:when, _, _} = ast, acc ->
        {ast, acc}

      {var, meta, context}, acc when is_atom(var) and is_atom(context) ->
        ast = {placeholder(var), meta, context}
        identifier = {:same, var}
        {ast, [identifier | acc]}

      {{:., meta, [module, name]}, _, args}, acc ->
        module =
          case module do
            {:__aliases__, _, parts} -> Module.concat(parts)
            module -> module
          end

        ast = {placeholder("#{module}.#{name}"), meta, args}
        identifier = {:remote_type, module, name, length(args)}
        {ast, [identifier | acc]}

      {name, meta, args} = ast, acc when is_atom(name) and is_list(args) ->
        arity = length(args)

        if operator?({name, arity}) do
          identifier = {:operator, name}
          {ast, [identifier | acc]}
        else
          ast = {placeholder(name), meta, args}

          identifier =
            cond do
              basic_type?({name, arity}) ->
                {:type, name, arity}

              built_in_type?({name, arity}) ->
                {:type, name, arity}

              true ->
                {:user_type, name, arity}
            end

          {ast, [identifier | acc]}
        end

      other, acc ->
        {other, acc}
    end)
  end

  defp placeholder(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> placeholder()
  end

  defp placeholder(binary) when is_binary(binary) do
    "_"
    |> String.duplicate(byte_size(binary))
    |> String.to_atom()
  end

  @basic_types [
    any: 0,
    none: 0,
    atom: 0,
    map: 0,
    pid: 0,
    port: 0,
    reference: 0,
    struct: 0,
    tuple: 0,
    float: 0,
    integer: 0,
    neg_integer: 0,
    non_neg_integer: 0,
    pos_integer: 0,
    list: 1,
    nonempty_list: 1,
    maybe_improper_list: 2,
    nonempty_improper_list: 2,
    nonempty_maybe_improper_list: 2
  ]

  @built_in_types [
    term: 0,
    arity: 0,
    as_boolean: 1,
    binary: 0,
    bitstring: 0,
    boolean: 0,
    byte: 0,
    char: 0,
    charlist: 0,
    nonempty_charlist: 0,
    fun: 0,
    function: 0,
    identifier: 0,
    iodata: 0,
    iolist: 0,
    keyword: 0,
    keyword: 1,
    list: 0,
    nonempty_list: 0,
    maybe_improper_list: 0,
    nonempty_maybe_improper_list: 0,
    mfa: 0,
    module: 0,
    no_return: 0,
    node: 0,
    number: 0,
    struct: 0,
    timeout: 0
  ]

  unary = [:@, :+, :-, :!, :^, :not, :~~~, :&]

  binary =
    [:., :*, :/, :+, :-, :++, :--, :.., :<>, :+++, :---, :^^^, :in, :"not in"] ++
      [:|>, :<<<, :>>>, :<<~, :~>>, :<~, :~>, :<~>, :<|>, :<, :>, :<=, :>=] ++
      [:==, :!=, :=~, :===, :!==, :&&, :&&&, :and, :||, :|||, :or, :=]

  @operators Enum.map(unary, &{&1, 1}) ++ Enum.map(binary, &{&1, 2})

  defp basic_type?(type) do
    type in @basic_types
  end

  defp built_in_type?(type) do
    type in @built_in_types
  end

  def operator?(type) do
    type in @operators
  end
end
