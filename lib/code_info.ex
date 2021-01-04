defmodule CodeInfo do
  def info(module) do
    {:docs_v1, _anno, _language, _content_type, doc, metadata, docs} = Code.fetch_docs(module)

    {:ok, types} = Code.Typespec.fetch_types(module)

    types =
      for {_kind, {name, _, args} = spec} <- types,
          into: %{} do
        {{name, length(args)}, spec}
      end

    types =
      for {{kind, name, arity}, _, signature, doc, metadata} <- docs,
          kind in [:type, :opaque, :typep],
          into: %{} do
        spec_string =
          types
          |> Map.fetch!({name, arity})
          |> Code.Typespec.type_to_quoted()
          |> Macro.to_string()

        map = %{
          kind: kind,
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_string: spec_string
        }

        {{name, arity}, map}
      end

    {:ok, specs} = Code.Typespec.fetch_specs(module)
    specs = Map.new(specs)

    functions =
      for {{:function, name, arity}, _, signature, doc, metadata} <- docs,
          into: %{} do
        spec_strings =
          case Map.fetch(specs, {name, arity}) do
            {:ok, specs} ->
              for spec <- specs do
                name
                |> Code.Typespec.spec_to_quoted(spec)
                |> Macro.to_string()
              end

            :error ->
              nil
          end

        map = %{
          doc: doc,
          doc_metadata: metadata,
          signature: signature,
          spec_strings: spec_strings
        }

        {{name, arity}, map}
      end

    %{
      functions: functions,
      types: types,
      doc: doc,
      doc_metadata: metadata
    }
  end
end
