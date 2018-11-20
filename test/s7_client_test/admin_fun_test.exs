defmodule AdminFunTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  test "set_connection_type function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.set_connection_type(state.pid, :PG)
        assert resp == :ok

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "set_connection_params function", state do
    case state.status do
      :connected ->
        resp =
          Snapex7.Client.set_connection_params(state.pid,
            ip: "192.168.1.100",
            local_tsap: 1,
            remote_tsap: 2
          )

        assert resp == :ok

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "connect_to function" do
    {:ok, pid} = Snapex7.Client.start_link()
    resp = Snapex7.Client.connect_to(pid, ip: "192.168.0.200", rack: 0, slot: 1)
    assert resp == {:error, %{eiso: nil, es7: nil, etcp: 113}}
    resp = Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    assert resp == :ok
  end

  test "connect/disconnect function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.disconnect(state.pid)
        assert resp == :ok

        resp = Snapex7.Client.connect(state.pid)
        assert resp == :ok

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "get_params/set_params function" do
    {:ok, pid} = Snapex7.Client.start_link()
    resp = Snapex7.Client.set_params(pid, 3, 800)
    assert resp == :ok
    resp = Snapex7.Client.get_params(pid, 3)
    assert resp == {:ok, 800}

    resp = Snapex7.Client.set_params(pid, 2, 400)
    assert resp == :ok
    resp = Snapex7.Client.get_params(pid, 2)
    assert resp == {:ok, 400}
  end
end
