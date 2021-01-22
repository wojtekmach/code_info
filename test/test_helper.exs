ExUnit.start()

defmodule TestHelper do
  def elixirc(code) do
    [{module, bytecode}] = Code.compile_string(code)
    dir = tmp_dir(code)
    beam_path = '#{dir}/#{module}.beam'
    File.write!(beam_path, bytecode)
    true = :code.add_path(dir)

    ExUnit.Callbacks.on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
      File.rm_rf!(dir)
    end)

    :ok
  end

  def erlc(module, code) do
    dir = tmp_dir(code)
    source_path = Path.join(dir, '#{module}.erl') |> String.to_charlist()
    File.write!(source_path, code)
    {:ok, module} = :compile.file(source_path, [:debug_info, outdir: dir])
    true = :code.add_path(dir)

    ExUnit.Callbacks.on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
      File.rm_rf!(dir)
    end)

    :ok
  end

  def edoc_to_chunk(module) do
    source_path = module.module_info(:compile)[:source]
    beam_path = :code.which(module)
    dir = :filename.dirname(source_path)
    xml_path = '#{dir}/#{module}.xml'
    chunk_path = '#{dir}/#{module}.chunk'

    docgen_dir = :code.lib_dir(:erl_docgen)
    cmd!("escript #{docgen_dir}/priv/bin/xml_from_edoc.escript -dir #{dir} #{source_path}")

    :docgen_xml_to_chunk.main(["app", xml_path, beam_path, "", chunk_path])
    docs_chunk = File.read!(chunk_path)
    {:ok, ^module, chunks} = :beam_lib.all_chunks(beam_path)
    {:ok, beam} = :beam_lib.build_module([{'Docs', docs_chunk} | chunks])
    File.write!(beam_path, beam)
  end

  defp tmp_dir(code) do
    dir = Path.join("tmp", :crypto.hash(:sha256, code) |> Base.url_encode64(case: :lower))
    File.mkdir_p!(dir)
    String.to_charlist(dir)
  end

  defp cmd!(command) do
    0 = Mix.shell().cmd(command)
  end
end
