defmodule CodeInfo.Utils do
  @moduledoc false

  def module(atom) when is_atom(atom), do: atom
  def module({:__aliases__, _, parts}), do: Module.concat(parts)
end
