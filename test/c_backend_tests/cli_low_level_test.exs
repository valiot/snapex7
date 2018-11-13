defmodule CliLowLevelTest do
  use ExUnit.Case, async: false
  doctest Snapex7

  @s7_msg <<0x32, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x04, 0x01, 0x12, 0x0a, 0x10, 0x02, 0x00, 0x04, 0x00, 0x01, 0x84, 0x00, 0x00, 0x10>>
  @s7_response <<0x32, 0x03, 0x00, 0x00, 0x01, 0x00, 0x00, 0x02, 0x00, 0x08, 0x00, 0x00, 0x04, 0x01, 0xff, 0x04, 0x00, 0x20, 0x42, 0xca, 0x00, 0x00, 0x00, 0x10>>

  setup do
    System.put_env("LD_LIBRARY_PATH", "./src") #checar como cambiar esto para que use :code.priv_dir
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'
    port =  Port.open({:spawn_executable, executable}, [{:args, []}, {:packet, 2}, :use_stdio, :binary, :exit_status])

    msg = {:connect_to, {"192.168.0.1", 0, 1}}
    send(port, {self(), {:command, :erlang.term_to_binary(msg)}})
    status =
      receive do
        {_, {:data, <<?r, response::binary>>}}  ->
          :erlang.binary_to_term(response)
        after
          10000  ->
            :error
      end

    %{port: port, status: status}
  end

  test "handle_iso_exchange_buffer", state do
    case state.status do
      :ok ->
        msg = {:iso_exchange_buffer, {String.length(@s7_msg), @s7_msg}} #{size, S7 pdu}
        send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

        c_response =
          receive do
            {_, {:data, <<?r, response::binary>>}} ->
              :erlang.binary_to_term(response)
            x ->
              IO.inspect(x)
              :error
          after
            1000 ->
              # Not sure how this can be recovered
              exit(:port_timed_out)
          end

        assert {:ok, @s7_response} == c_response
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
