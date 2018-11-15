defmodule BlockOrientedFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  # functions no supported by PLC s7-1200
  test "full_upload function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.full_upload(state.pid, :OB, 0x41, 4)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "upload function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.upload(state.pid, :OB, 0x41, 4)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "download function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.download(state.pid, 0x38, <<0x02, 0x34, 0x35>>)
        assert resp == {:error, %{eiso: nil, es7: :errCliInvalidBlockSize, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "delete function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.delete(state.pid, :OB, 0x03)
        assert resp == {:error, %{eiso: nil, es7: :errCliDeleteRefused, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "db_get function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.db_get(state.pid, 0)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "db_fill function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.db_fill(state.pid, 2, 0)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

end

