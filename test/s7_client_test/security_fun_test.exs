defmodule SecurityFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  # functions no supported by PLC s7-1200
  test "set_session_password function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.set_session_password(state.pid, "holahola")
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}} #when PLC is running
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  # functions no supported by PLC s7-1200
  test "clear_session_password function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.clear_session_password(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}} #when PLC is running
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_protection function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_protection(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliItemNotAvailable, etcp: nil}} #when PLC is running
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

end
