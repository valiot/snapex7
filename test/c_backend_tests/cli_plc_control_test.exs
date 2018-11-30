defmodule CliPlcControlTest do
  use ExUnit.Case, async: false
  doctest Snapex7
  # We don't have the way to test this function
  # (we've a plc s7-1200 and snap7 server doesn't support these functions)
  # These tests only help us to track the input variables.
  setup do
    snap7_dir = :code.priv_dir(:snapex7) |> List.to_string()
    System.put_env("LD_LIBRARY_PATH", snap7_dir)
    System.put_env("DYLD_LIBRARY_PATH", snap7_dir)
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

  test "handle_plc_hot_start", state do
    case state.status do
      :ok ->
        # NA
        msg = {:plc_hot_start, nil}
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

        # when PLC is running
        assert c_response == {:error, %{eiso: nil, es7: :errCliCannotStartPLC, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_plc_cold_start", state do
    case state.status do
      :ok ->
        # NA
        msg = {:plc_cold_start, nil}
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

        # when PLC is running
        assert c_response == {:error, %{eiso: nil, es7: :errCliCannotStartPLC, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_plc_stop", state do
    case state.status do
      :ok ->
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

        # PLC s7-1200 cannot be stopped
        assert c_response == {:error, %{eiso: nil, es7: :errCliCannotStopPLC, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_copy_ram_to_rom", state do
    case state.status do
      :ok ->
        # timeout
        msg = {:copy_ram_to_rom, 300}
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

        # when PLC is running
        assert c_response == {:error, %{eiso: nil, es7: :errCliCannotCopyRamToRom, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_compress", state do
    case state.status do
      :ok ->
        # timeout
        msg = {:compress, 300}
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

        # when the PLC is runnig
        assert c_response == {:error, %{eiso: nil, es7: :errCliCannotCompress, etcp: nil}}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_plc_status", state do
    case state.status do
      :ok ->
        # NA
        msg = {:get_plc_status, nil}
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

        # when the PLC is running
        assert c_response == {:ok, :S7CpuStatusRun}

      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end
end
