defmodule DateTimeFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  # functions no supported by PLC s7-1200
  test "get_plc_date_time function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_plc_date_time(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliItemNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "set_plc_date_time function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.set_plc_date_time(state.pid,
                                                    sec: 20,
                                                    min: 59,
                                                    hour: 23,
                                                    mday: 23,
                                                    mon: 12,
                                                    year: 1990,
                                                    wday: 3,
                                                    yday: 320,
                                                    isdst: 1)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "set_plc_system_date_time function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.set_plc_system_date_time(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
