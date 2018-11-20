defmodule SystemInfoFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  test "read_szl function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.read_szl(state.pid, 0x0111, 0x0006)
        id = <<0, 6>>
        module_num = "6ES7 211-1AE40-0XB0"
        tail = <<32, 0, 0, 0, 7, 32, 32>>
        assert resp == {:ok, id <> module_num <> tail}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "read_szl_list function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.read_szl_list(state.pid)
        assert resp == {:ok, [0, 17, 273, 3857, 1060, 305]}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_order_code function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_order_code(state.pid)
        assert resp == {:ok, [Code: "6ES7 211-1AE40-0XB0 ", Version: "4.2.1"]}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_cpu_info function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_cpu_info(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliItemNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_cp_info function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_cp_info(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliItemNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
