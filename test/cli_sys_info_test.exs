defmodule CliSysInfoTest do
  use ExUnit.Case, async: false
  doctest Snapex7

  # We don't have the way to test this function
  # (we've a plc s7-1200 and snap7 server doesn't support these functions)
  # These tests only help us to track the input variables.

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

  test "handle_read_szl", state do
    case state.status do
      :ok ->
        msg = {:read_szl, {0x0111, 0x0006}} #{ID, index}
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
        id = <<0,6>>
        module_num = "6ES7 211-1AE40-0XB0"
        tail =  <<32, 0, 0, 0, 7, 32, 32>>
        assert c_response == {:ok, id <> module_num <> tail}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_read_szl_list", state do
    case state.status do
      :ok ->
        msg = {:read_szl_list, nil} #NA
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

        assert c_response == {:ok, [0, 17, 273, 3857, 1060, 305]}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_order_code", state do
    case state.status do
      :ok ->
        msg = {:get_order_code, nil} #NA
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

        assert c_response == {:ok, [Code: "6ES7 211-1AE40-0XB0 ", Version: "4.2.1"]}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_cpu_info", state do
    case state.status do
      :ok ->
        msg = {:get_cpu_info, nil} #NA
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

        assert c_response == {:ok, [Code: "6ES7 211-1AE40-0XB0 ", Version: "4.2.1"]}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handle_get_cp_info", state do
    msg = {:get_cp_info, nil} #NA
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

        assert c_response == {:ok, [Code: "6ES7 211-1AE40-0XB0 ", Version: "4.2.1"]}
    case state.status do
      :ok ->
        msg = {:get_cp_info, nil} #NA
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

        assert c_response == {:ok, [Code: "6ES7 211-1AE40-0XB0 ", Version: "4.2.1"]}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

end
