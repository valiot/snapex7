defmodule CliMiscTest do
  use ExUnit.Case, async: false
  doctest Snapex7

  setup do
    # checar como cambiar esto para que use :code.priv_dir
    System.put_env("LD_LIBRARY_PATH", "./src")
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    msg = {:connect_to, {"192.168.0.1", 0, 1}}
    send(port, {self(), {:command, :erlang.term_to_binary(msg)}})

    status =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)
      after
        10000 ->
          :error
      end

    %{port: port, status: status}
  end

  test "handle_get_exec_time", state do
    case state.status do
      :ok ->
        # NA
        msg = {:get_exec_time, nil}
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

        {:ok, num} = c_response
        assert is_integer(num)

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_last_error", state do
    case state.status do
      :ok ->
        # no supported function (returns an error).
        # NA
        msg = {:plc_stop, nil}
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

        {:error, snap7_error} = c_response

        # NA
        msg = {:get_last_error, nil}
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

        {:ok, last_error} = c_response
        assert snap7_error == last_error

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_pdu_length", state do
    case state.status do
      :ok ->
        # NA
        msg = {:get_pdu_length, nil}
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

        {:ok, pdu} = c_response
        assert pdu == [Requested: 480, Negotiated: 240]

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_connected", state do
    case state.status do
      :ok ->
        # NA
        msg = {:get_connected, nil}
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

        assert c_response == {:ok, true}

        # disconnect
        msg = {:disconnect, nil}
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

        # NA
        msg = {:get_connected, nil}
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

        assert c_response == {:ok, false}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
