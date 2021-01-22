defmodule CodeInfo.SpecAST do
  @doc ~S"""
  Converts AST into string.

  If set, `format_fun` allows formatting types. It can receive one of the
  following:

    * `{:type, name, arity}`

    * `{:user_type, name, arity}`

    * `{:remote_type, module, name, arity}`

  and must return a string rendering that type.

  This is useful to autolink types:

      format_fun = fn
        {:remote_type, module, name, arity} ->
          url = "#{module}.html##{name}/#{arity}"
          text = "#{module}:#{name}"
          ~s|<a href="#{href}">#{text}</a>|

        ...
      end

  """
  def to_string(ast, language, format_fun \\ nil)

  def to_string(ast, language, nil) do
    {name, _, args} = ast
    arity = length(args)
    language.spec_to_string(ast, :type, name, arity)
  end

  def to_string(ast, language, format_fun) do
    {ast, acc} = f(ast)
    string = to_string(ast, language)
    Process.put({__MODULE__, :placeholders}, acc)

    Regex.replace(~r/x+/, string, fn _placeholder ->
      [head | tail] = Process.get({__MODULE__, :placeholders})
      Process.put({__MODULE__, :placeholders}, tail)

      case head do
        {:var, var} ->
          "#{var}"

        other ->
          format_fun.(other)
      end
    end)
  end

  defp f(ast) do
    f = fn
      {:var, anno, var}, acc ->
        ast = {:var, anno, placeholder(var)}
        identifier = {:var, var}
        {ast, [identifier | acc]}

      {:type, _, :union, _} = ast, acc ->
        {ast, acc}

      {:type, anno, name, args}, acc when is_atom(name) ->
        placeholder = placeholder(name)
        ast = {:type, anno, placeholder, args}
        identifier = {:type, name, length(args)}
        {ast, [identifier | acc]}

      {:user_type, anno, name, args}, acc ->
        placeholder = placeholder(name)
        ast = {:user_type, anno, placeholder, args}
        identifier = {:user_type, name, length(args)}
        {ast, [identifier | acc]}

      {:remote_type, anno, [{:atom, _, module}, {:atom, _, name}, args]}, acc ->
        # FIXME remove :elixir
        placeholder =
          if module == :elixir do
            placeholder(name)
          else
            # FIXME remove Elixir.
            module = module |> to_string() |> String.trim_leading("Elixir.")
            placeholder("#{module}.#{name}")
          end

        ast = {:user_type, anno, placeholder, args}
        identifier = {:remote_type, module, name, length(args)}
        {ast, [identifier | acc]}

      ast, acc ->
        {ast, acc}
    end

    {name, inner, args} = ast
    {args, acc} = prewalk(args, [], f)
    {inner, acc} = prewalk(inner, acc, f)
    acc = Enum.reverse(acc)
    ast = {name, inner, args}
    {ast, acc}
  end

  defp prewalk(ast, acc, f) do
    {ast, acc} = f.(ast, acc)
    do_prewalk(ast, acc, f)
  end

  defp do_prewalk({name, anno, args}, acc, f) when is_atom(name) do
    {args, acc} = do_prewalk_args(args, acc, f)
    {{name, anno, args}, acc}
  end

  defp do_prewalk({name, anno, :union, args}, acc, f) when is_atom(name) do
    {args, acc} = do_prewalk_args(args, acc, f)
    {{name, anno, :union, args}, acc}
  end

  defp do_prewalk({:type, anno, name, args}, acc, f) when is_atom(name) do
    {args, acc} = do_prewalk_args(args, acc, f)
    {{:type, anno, name, args}, acc}
  end

  defp do_prewalk({:user_type, anno, name, args}, acc, f) when is_atom(name) do
    {args, acc} = do_prewalk_args(args, acc, f)
    {{:user_type, anno, name, args}, acc}
  end

  defp do_prewalk(args, acc, f) when is_list(args) do
    do_prewalk_args(args, acc, f)
  end

  defp do_prewalk_args(args, acc, _f) when is_atom(args) do
    {args, acc}
  end

  defp do_prewalk_args(args, acc, f) when is_list(args) do
    Enum.map_reduce(args, acc, fn x, acc ->
      {x, acc} = f.(x, acc)
      do_prewalk(x, acc, f)
    end)
  end

  defp placeholder(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> placeholder()
  end

  defp placeholder(binary) when is_binary(binary) do
    "x"
    |> String.duplicate(byte_size(binary))
    |> String.to_atom()
  end
end
