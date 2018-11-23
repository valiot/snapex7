defmodule CDriverTest do
  use ExUnit.Case
  doctest Snapex7

  setup do
    snap7_dir = :code.priv_dir(:snapex7) |> List.to_string()
    System.put_env("LD_LIBRARY_PATH", snap7_dir)
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'

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

  # test "checking ei functions", state do
  #   data1 = %{        #DB1
  #     area: 132,
  #     wordlen: 2,
  #     dbnumber: 1,
  #     start: 2,
  #     amount: 4
  #   }

  #   data2 = %{        #PE0
  #     area: 129,
  #     wordlen: 2,
  #     dbnumber: 1,
  #     start: 0,
  #     amount: 1
  #   }
  #   msg = {:test, {2, [data1, data2]}}
  #   send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end

  #   assert c_response == {:ok, 2}

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  #   c_response =
  #     receive do
  #       {_, {:data, <<?r, response::binary>>}} ->
  #         :erlang.binary_to_term(response)
  #       x ->
  #         IO.inspect(x)
  #         :error
  #     after
  #       1000 ->
  #         # Not sure how this can be recovered
  #         exit(:port_timed_out)
  #     end
  #   IO.puts("#{inspect(c_response)}")

  # end
end
