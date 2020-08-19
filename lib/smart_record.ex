defmodule SmartRecord do
  @moduledoc """
  Documentation for SmartRecord.
  """

  def new(top_mod, rec_name, field_defaults) do
    {fields, defaults} = Enum.unzip(field_defaults)
    size = Enum.count(fields) + 1
    name = String.to_atom(Macro.camelize(to_string(rec_name)))
    rmod = Module.concat(top_mod, name)
    field_idxs = Enum.with_index(fields, 1)
    wrap1 = &(for {f, x} <- &1, do: {[f], x})

    SmartGlobal.new(
      rmod,
      %{
        name: [{[], rec_name}],
        size: [{[], size}],
        idxs: [{[], 1..size}],
        fields: [{[], fields}],
        field_idxs: [{[], field_idxs}],
        defaults: [{[], defaults}],
        field_defaults: [{[], field_defaults}],
        field: Enum.map(field_idxs, fn {f, i} -> {[i], f} end),
        idx: wrap1.(field_idxs) ++ [{[:_], nil}],
        default: wrap1.(field_defaults) ++ [{[:_], nil}],
        new: [{[], {:"$call", SmartRecord, :new, [rmod]}}],
        get: [{[{:var, :r}, {:var, :f}],
               {:"$call", SmartRecord, :get, [rmod, {:var, :r}, {:var, :f}, nil]}},
              {[{:var, :r}, {:var, :f}, {:var, :default}],
               {:"$call", SmartRecord, :get, [rmod, {:var, :r}, {:var, :f}, {:var, :default}]}}],
        get!: [{[{:var, :r}, {:var, :f}],
                {:"$call", SmartRecord, :get!, [rmod, {:var, :r}, {:var, :f}]}}],
        lookup: [{[{:var, :r}, {:var, :f}],
                  {:"$call", SmartRecord, :lookup, [rmod, {:var, :r}, {:var, :f}]}}],
        from_list: [{[{:var, :l}],
                     {:"$call", SmartRecord, :from_list, [rmod, {:var, :l}]}}],
        from_map: [{[{:var, :m}], {:"$call", SmartRecord, :from_map, [rmod, {:var, :m}]}}],
        to_list: [{[{:var, :r}], {:"$call", SmartRecord, :to_list, [rmod, {:var, :r}]}}],
        to_map: [{[{:var, :r}], {:"$call", SmartRecord, :to_map, [rmod, {:var, :r}]}}]
      }
    )
  end


  def reduce(kvs, rec, f) do
    for {k, v} <- kvs, reduce: rec,
      do: (rec -> f.(rec, {k, v}))
  end

  def reduce(kvs, rec, acc, f) do
    for {k, v} <- kvs, reduce: {rec, acc},
      do: ({rec, acc} -> f.(rec, acc, {k, v}))
  end

  def new(mod) do
    rec = :erlang.make_tuple(mod.size(), nil)
    {_, rec} =
      Enum.reduce(mod.field_defaults(),
        {2, :erlang.setelement(1, rec, mod.name())},
        fn {_, d}, {i, rec} -> {i + 1, :erlang.setelement(i, rec, d)} end)
    rec
  end

  def get(mod, r, field, default) do
    case lookup(mod, r, field) do
      {:ok, v} -> v
      :not_found -> default
    end
  end

  def get!(mod, r, field) do
    elem(r, mod.idx(field))
  end

  def lookup(mod, r, field) do
    idx = mod.idx(field)
    idx && {:ok, elem(r, idx)} || :not_found
  end

  def from_list(mod, l) do
    reduce(l, mod.new(), fn r, {k, v} ->
      idx = mod.idx(k)
      idx && :erlang.setelement(idx + 1, r, v) || r
    end)
  end

  def to_list(mod, r) do
    {_rec, acc} =
      reduce(mod.field_idxs(), r, [],
        fn r, acc, {f, i} -> {r, [{f, elem(r, i)} | acc]} end)
    Enum.reverse(acc)
  end

  def to_map(mod, r) do
    {_rec, acc} =
      reduce(mod.field_idxs(), r, %{},
        fn r, acc, {f, i} -> {r, Map.put(acc, f, elem(r, i))} end)
    acc
  end

  def from_map(mod, m) do
    reduce(mod.field_idxs(), mod.new(),
      fn r, {f, i} -> :erlang.setelement(i + 1, r, Map.get(m, f, nil)) end)
  end


end
