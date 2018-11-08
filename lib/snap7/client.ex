defmodule Snapex7.Client do

  use GenServer

  defmodule State do
    @moduledoc false

    # port: C port process
    # controlling_process: where events get sent
    # queued_messages: queued messages when in passive mode
    # ip: the address of the server
    # rack: the rack of the server.
    # slot: the slot of the server.
    # is_active: active or passive mode
    defstruct port: nil,
              controlling_process: nil,
              queued_messages: [],
              ip: nil,
              rack: nil,
              slot: nil,
              state: nil,
              is_active: true
  end

   @doc """
  Start up a Client GenServer.
  """
  @spec start_link([term]) :: {:ok, pid} | {:error, term}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @spec connect_to(GenServer.server(), term()) :: :ok  | {:error, term}
  def connect_to(pid, opts \\ []) do
    GenServer.call(pid, {:connect_to, opts})
  end

  def init([]) do
    System.put_env("LD_LIBRARY_PATH", "./src") #checar como cambiar esto para que use :code.priv_dir
    executable = :code.priv_dir(:snapex7) ++ '/s7_client.o'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    state = %State{port: port}
    {:ok, state}
  end

  def handle_call({:connect_to, opts}, {_from_pid, _}, state) do
    ip = Keyword.get(opts, :ip, nil)
    rack = Keyword.get(opts, :rack, 0)
    slot = Keyword.get(opts, :slot,  0)

    response = call_port(state, :connect_to, {ip, rack, slot})

    new_state = %State{state | state: :connected, ip: ip, rack: rack, slot: slot}

    {:reply, response, new_state}
  end


  defp call_port(state, command, arguments, timeout \\ 4000) do
    msg = {command, arguments}
    send(state.port, {self(), {:command, :erlang.term_to_binary(msg)}})
    # Block until the response comes back since the C side
    # doesn't want to handle any queuing of requests. REVISIT
    receive do
      {_, {:data, <<?r, response::binary>>}} ->
        :erlang.binary_to_term(response)
    after
      timeout ->
        # Not sure how this can be recovered
        exit(:port_timed_out)
    end
  end

end
