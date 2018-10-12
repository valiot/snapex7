defmodule CDriverTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    System.put_env("LD_LIBRARY_PATH", "./src") #checar como cambiar esto para que use :code.priv_dir
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'
    port =  Port.open({:spawn_executable, executable}, [{:args, []}, {:packet, 2}, :use_stdio, :binary, :exit_status])
    %{port: port}
  end

  test "Erlang - C driver test", state do
    msg = {:test, "x"}
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
    assert c_response == :ok
  end

  test "set_connection_type test", state do
    msg = {:set_connection_type, 1}
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

    assert c_response == :ok
  end

  test "handle_set_connection_params test", state do
    msg = {:set_connection_params, {"192.168.1.100", 1, 2}}
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

    assert c_response == :ok
  end

  test "handle_connect_to test", state do
    msg = {:connect_to, {"192.168.0.1", 0, 1}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)
        x ->
          IO.inspect(x)
          :error
      after
        5000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end
    d_response =
      case c_response do
        {:error, x} ->
          IO.puts("connected_to response is #{inspect(x)}")
          :error
        :ok ->
          :ok
      end
    #no plc connected or connected
    assert d_response == :error || d_response == :ok
  end

  test "handle_connect test", state do
    msg = {:connect, nil}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)
        x ->
          IO.inspect(x)
          :error
      after
        5000 ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end
    d_response =
      case c_response do
        {:error, x} ->
          IO.puts("connect response is #{inspect(x)}")
          :error
        :ok ->
          :ok
      end
    #no plc connected or connected
    assert d_response == :error || d_response == :ok
  end

  test "handler_disconnect test", state do
    msg = {:disconnect, 1}
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

    assert c_response == :ok
  end

end
