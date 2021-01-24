defmodule CodeInfo.Language.Erlang do
  @behaviour CodeInfo.Language

  @impl true
  def functions(module) do
    functions_added_by_the_compiler = [
      {:behaviour_info, 1},
      {:module_info, 0},
      {:module_info, 1},
      {:record_info, 2}
    ]

    module.module_info(:exports) -- functions_added_by_the_compiler
  end

  @impl true
  def spec_to_string(spec, kind, name, arity) when kind in [:function, :callback] do
    kind =
      case kind do
        :function -> :spec
        :callback -> :callback
      end

    {:attribute, 0, kind, {{name, arity}, [spec]}}
    |> :erl_pp.form()
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  def spec_to_string(spec, :type, _name, _arity) do
    {:attribute, 0, :type, spec}
    |> :erl_pp.form()
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  # for debugging
  @doc false
  def get_abstract_code(module) do
    {^module, bin, _} = :code.get_object_code(module)

    {:ok, {^module, [debug_info: {:debug_info_v1, backend, data}]}} =
      :beam_lib.chunks(bin, [:debug_info])

    {:ok, abstract_code} = backend.debug_info(:erlang_v1, module, data, [])
    abstract_code
  end
end
