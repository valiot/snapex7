defmodule CDriverTest do
  use ExUnit.Case
  doctest Snapex7

   # We need to implement S7 Server behavior in order to make a proper tests.
   # we have a PLC that doesn't supports these functions (S7-1200).

  setup do
    System.put_env("LD_LIBRARY_PATH", "./src") #checar como cambiar esto para que use :code.priv_dir
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'
    port =  Port.open({:spawn_executable, executable}, [{:args, []}, {:packet, 2}, :use_stdio, :binary, :exit_status])
    %{port: port}
  end

  # test "handler_list_blocks", state do
  #   msg = {:test, 1}
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

  #   assert c_response == :ok

  # end

  #  test "handler_list_blocks_of_type", state do
  #   msg = {:list_blocks_of_type, {0x38, 2}}
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

  #   assert c_response == :ok
  # end

  # test "handler_get_ag_block_info test", state do
  #   msg = {:get_ag_block_info, {0x38, 2}}
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

  #   assert c_response == :ok
  # end

  # test "handler_get_pg_block_info test", state do
  #   msg = {:get_pg_block_info, {3, <<0x01, 0x02, 0x03>>}}
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

  #   assert c_response == :ok
  # end

end
