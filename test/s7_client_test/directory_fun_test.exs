defmodule DirectoryFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  # function no supported by PLC s7-1200
  test "list_blocks function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.list_blocks(state.pid)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "list_blocks_of_type function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.list_blocks_of_type(state.pid, :OB, 2)
        assert resp == {:error, %{eiso: nil, es7: :errCliItemNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_ag_block_info function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_ag_block_info(state.pid, :OB, 2)
        assert resp == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_pg_block_info function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.get_pg_block_info(state.pid, <<0x01, 0x02, 0x03>>)
        assert resp == {:error, %{eiso: nil, es7: :errCliInvalidBlockSize, etcp: nil}}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
