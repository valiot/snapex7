defmodule CliBlockOrientedTest do
  use ExUnit.Case, async: false
  doctest Snapex7

  # We don't have the way to test this function
  # (we've a plc s7-1200 and snap7 server doesn't support these functions)
  # These tests only help us to track the input variables for c code.

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

  test "handle_full_update", state do
    case state.status do
      :ok ->
        # {Blocktype, BlockNum, size}
        msg = {:full_upload, {0x38, 0x41, 0x04}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_update", state do
    case state.status do
      :ok ->
        # {Blocktype, BlockNum, size}
        msg = {:upload, {0x38, 0x41, 0x04}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_upload", state do
    case state.status do
      :ok ->
        # {Blocktype, BlockNum, size}
        msg = {:upload, {0x38, 0x41, 0x04}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_download", state do
    case state.status do
      :ok ->
        # {Blocknum, size, data (bitstring)}
        msg = {:download, {0x38, 0x03, <<0x02, 0x34, 0x35>>}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliInvalidBlockSize, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_delete", state do
    case state.status do
      :ok ->
        # {Blocktype, blocknumber}
        msg = {:delete, {0x38, 0x03}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliDeleteRefused, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_db_get", state do
    case state.status do
      :ok ->
        # {Blocktype, blocknumber}
        msg = {:db_get, {0x38, 0x03}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_db_fill", state do
    case state.status do
      :ok ->
        # {DBNumber, fillchar}
        msg = {:db_fill, {0x38, 0x03}}
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

        assert c_response == {:error, %{eiso: nil, es7: :errCliFunNotAvailable, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
