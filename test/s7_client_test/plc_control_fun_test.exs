defmodule PlcControlFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  # functions no supported by PLC s7-1200
  test "plc_hot_start function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.plc_hot_start(state.pid)
        # when PLC is running
        assert resp == {:error, %{eiso: nil, es7: :errCliCannotStartPLC, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "plc_cold_start function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.plc_cold_start(state.pid)
        # when PLC is running
        assert resp == {:error, %{eiso: nil, es7: :errCliCannotStartPLC, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "plc_stop function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.plc_stop(state.pid)
        # when PLC is running
        assert resp == {:error, %{eiso: nil, es7: :errCliCannotStopPLC, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "copy_ram_to_rom function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.copy_ram_to_rom(state.pid)
        # when PLC is running
        assert resp == {:error, %{eiso: nil, es7: :errCliCannotCopyRamToRom, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "compress function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.compress(state.pid, 300)
        # when PLC is running
        assert resp == {:error, %{eiso: nil, es7: :errCliCannotCompress, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_plc_status function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_plc_status(state.pid)
        # when the PLC is running
        assert resp == {:ok, :S7CpuStatusRun}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
