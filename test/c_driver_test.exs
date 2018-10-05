defmodule CDriverTest do
  use ExUnit.Case
  doctest Snapex7

  test "Erlang - C driver test" do
    executable = :code.priv_dir(:snapex7) ++ '/s7_client'
    port =  Port.open({:spawn_executable, executable}, [{:args, []}, {:packet, 2}, :use_stdio, :binary, :exit_status])
    msg = {:test, "x"}
    send(port, {self(), {:command, :erlang.term_to_binary(msg)}})
    timeout = 1000

    c_response =
      receive do
        {_, {:data, <<?r, response::binary>>}} ->
          :erlang.binary_to_term(response)
      after
        timeout ->
          # Not sure how this can be recovered
          exit(:port_timed_out)
      end

    assert c_response == :ok
  end

end
