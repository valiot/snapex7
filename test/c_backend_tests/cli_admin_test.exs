defmodule CliAdminFuncTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    # checar como cambiar esto para que use :code.priv_dir
    snap7_dir = :code.priv_dir(:snapex7) |> List.to_string()
    System.put_env("LD_LIBRARY_PATH", snap7_dir)
    System.put_env("DYLD_LIBRARY_PATH", snap7_dir)
    executable = :code.priv_dir(:snapex7) ++ ~c"/s7_client.o"

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    %{port: port}
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
    #
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

    # no plc connected or connected
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
        {:error, _x} ->
          :error

        :ok ->
          :ok
      end

    # no plc connected or connected
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

  test "handler_get_params/handler_set_params test", state do
    msg = {:set_params, {2, 103}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 2}
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
          exit(:port_timed_out)
      end

    assert c_response == {:ok, 103}

    msg = {:set_params, {3, 800}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 3}
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

    assert c_response == {:ok, 800}

    msg = {:set_params, {4, 20}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 4}
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

    assert c_response == {:ok, 20}

    msg = {:set_params, {5, 3500}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 5}
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

    assert c_response == {:ok, 3500}

    msg = {:set_params, {7, 512}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 7}
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

    assert c_response == {:ok, 512}

    msg = {:set_params, {8, 1}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 8}
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

    assert c_response == {:ok, 1}

    msg = {:set_params, {9, 127}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 9}
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

    assert c_response == {:ok, 127}

    msg = {:set_params, {10, 500}}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)

      x ->
        IO.inspect(x)
        :error
    after
      5000 ->
        exit(:port_timed_out)
    end

    msg = {:get_params, 10}
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

    assert c_response == {:ok, 500}
  end
end
