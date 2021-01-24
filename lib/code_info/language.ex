defmodule CodeInfo.Language do
  @callback functions(module()) :: [{atom(), arity()}]

  @callback spec_to_string(spec :: term(), kind :: atom(), name :: term(), arity()) :: String.t()
end
