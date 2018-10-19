defmodule CliDataIoTest do
  use ExUnit.Case, async: false
  doctest Snapex7

  # We need to implement S7 Server behavior in order to make a proper tests.
  # this tests are done connected to a physical PLC

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

  test "handler_write_area/read_area (DB) test", state do
    case state.status do
      :ok ->
        msg = {:write_area, {0x84, 1, 2, 4, 2, <<0x42, 0xcb, 0x00, 0x00>>}}
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

        msg = {:read_area, {0x84, 1, 2, 4, 2}}
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

        assert c_response == {:ok, <<0x42,0xcb, 0x00, 0x00>>}

        msg = {:write_area, {0x84, 1, 2, 4, 2, <<0x42, 0xca, 0x00, 0x00>>}}
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

        msg = {:read_area, {0x84, 1, 2, 4, 2}}
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

        assert c_response == {:ok, <<0x42,0xca, 0x00, 0x00>>}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handler_db_write/db_read test", state do
    case state.status do
      :ok ->
          msg = {:db_write, {1, 2, 4, <<0x42, 0xcb, 0x00, 0x00>>}}
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

          msg = {:db_read, {1, 2, 4}}
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

          assert c_response == {:ok, <<0x42,0xcb, 0x00, 0x00>>}

          msg = {:db_write, {1, 2, 4, <<0x42, 0xca, 0x00, 0x00>>}}
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

          msg = {:db_read, {1, 2, 4}}
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

          assert c_response == {:ok, <<0x42,0xca, 0x00, 0x00>>}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  test "handler_ab_write/ab_read test", state do
    case state.status do
      :ok ->
          msg = {:ab_write, {0, 1, <<0x0F>>}}
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

          msg = {:ab_read, {0,1}}
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

          assert c_response == {:ok, <<0x0F>>}
          Process.sleep(500);
          msg = {:ab_write, {0, 1, <<0x00>>}}
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

          msg = {:ab_read, {0, 1}}
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

          assert c_response == {:ok, <<0x00>>}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

  #eb_write doesn't make sense...
  test "handler_eb_read test", state do
    case state.status do
      :ok ->
          msg = {:eb_read, {0,1}}
          send(port, {self(), {:command, :erlang.term_to_binary(msg)}})

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

          assert c_response == {:ok, <<0x08>>}
      _ ->
        IO.puts("(#{__MODULE__}) Not connected")
    end
  end

end
