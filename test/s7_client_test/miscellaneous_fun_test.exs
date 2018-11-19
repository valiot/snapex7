defmodule MiscellaneousFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  test "get_exec_time function", state do
    case state.status do
      :connected ->
        {:ok, resp_num} = Snapex7.Client.get_exec_time(state.pid)
        assert resp_num |> is_integer
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_last_error function", state do
    case state.status do
      :connected ->
        {:error, error} = Snapex7.Client.plc_stop(state.pid)
        resp = Snapex7.Client.get_last_error(state.pid)
        assert resp == {:ok, error}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_pdu_length function", state do
    case state.status do
      :connected ->
        {:ok, pdu} = Snapex7.Client.get_pdu_length(state.pid)
        assert pdu == [Requested: 480, Negotiated: 240]
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_connected function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_connected(state.pid)
        assert resp == {:ok, true}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
