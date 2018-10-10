defmodule CDriverTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    System.put_env("LD_LIBRARY_PATH", "./src") #checar como cambiar esto para que use :code.priv_dir
    executable = :code.priv_dir(:snapex7) ++ '/s7_client'
    port =  Port.open({:spawn_executable, executable}, [{:args, []}, {:packet, 2}, :use_stdio, :binary, :exit_status])
    %{port: port}
  end

  test "Erlang - C driver test", state do
    msg = {:test, "x"}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})
    timeout = 1000
    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)
        x ->
          IO.inspect(x)
          :error
      after
        timeout ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end
    assert c_response == :ok
  end

  test "set_connection_type test", state do
    msg = {:set_connection_type, 1}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})
    timeout = 1000
    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)
        x ->
          IO.inspect(x)
          :error
      after
        timeout ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok
  end

end
