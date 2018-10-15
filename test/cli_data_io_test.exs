defmodule CliDataIoTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    System.put_env("LD_LIBRARY_PATH", "./src") #checar como cambiar esto para que use :code.priv_dir
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'
    port =  Port.open({:spawn_executable, executable}, [{:args, []}, {:packet, 2}, :use_stdio, :binary, :exit_status])
    %{port: port}
  end

  test "handler_read_area test", state do
    msg = {:read_area, {1,2,3,4,5}}
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

    assert c_response == {:error, %{eiso: :errIsoSendPacket, es7: nil, etcp: 110}}
  end

  test "handler_write_area test", state do
    msg = {:write_area, {0x84, 1, 1, 3, 1, <<0x01, 0x02, 0x03>>}}
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

    assert c_response == {:error, %{eiso: :errCliAddressOutOfRange, es7: nil, etcp: 110}}
  end

end
