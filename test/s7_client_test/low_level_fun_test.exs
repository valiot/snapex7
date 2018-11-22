defmodule LowLevelFunTest do
  use ExUnit.Case, async: false
  doctest Snapex7

  @s7_msg <<0x32, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x0E, 0x00, 0x00, 0x04, 0x01, 0x12, 0x0A,
            0x10, 0x02, 0x00, 0x04, 0x00, 0x01, 0x84, 0x00, 0x00, 0x10>>
  @s7_response <<0x32, 0x03, 0x00, 0x00, 0x01, 0x00, 0x00, 0x02, 0x00, 0x08, 0x00, 0x00, 0x04,
                 0x01, 0xFF, 0x04, 0x00, 0x20, 0x42, 0xCA, 0x00, 0x00, 0x00, 0x10>>

  setup do
    {:ok, pid} = Snapex7.Client.start_link()
    Snapex7.Client.connect_to(pid, ip: "192.168.0.1", rack: 0, slot: 1)
    {:ok, state} = :sys.get_state(pid) |> Map.fetch(:state)
    %{pid: pid, status: state}
  end

  test "iso_exchange_buffer function", state do
    case state.status do
      :connected ->
        resp = Snapex7.Client.iso_exchange_buffer(state.pid, @s7_msg)
        # when PLC is running
        assert resp == {:ok, @s7_response}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
