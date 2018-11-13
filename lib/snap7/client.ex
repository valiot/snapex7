defmodule Snapex7.Client do

  use GenServer

  @block_types [
                OB: 0x38,
                DB: 0x41,
                SDB: 0x42,
                FC: 0x43,
                SFC: 0x44,
                FB: 0x45,
                SFB: 0x46
              ]

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
              is_active: false
  end

  @doc """
  Start up a Snap7 Client GenServer.
  """
  @spec start_link([term]) :: {:ok, pid} | {:error, term}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @doc """
  Stop the Snap7 Client GenServer.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  # Administrative functions.

  @type connect_opt ::
          {:ip, binary}
          | {:rack, 0..7}
          | {:slot, 1..31}

  @doc """
  Connect to a S7 server.
  The following options are available:

    * `:active` - (`true` or `false`) specifies whether data is received as
       messages or by calling "Data I/O functions".

    * `:ip` - (string) PLC/Equipment IPV4 Address (e.g., "192.168.0.1")

    * `:rack` - (int) PLC Rack number (0..7).

    * `:slot` - (int) PLC Slot number (1..31).

  For more info see pg. 96 form Snap7 docs.
  """
  @spec connect_to(GenServer.server(), [connect_opt]) :: :ok  | {:error, map()}
  def connect_to(pid, opts \\ []) do
    GenServer.call(pid, {:connect_to, opts})
  end

  # Directory functions

  @doc """
  This function returns the AG blocks amount divided by type.
  """
  @spec list_blocks(GenServer.server()) :: {:ok, list}  | {:error, map()}
  def list_blocks(pid)  do
    GenServer.call(pid, :list_blocks)
  end

  @doc """
  This function returns the AG list of a specified block type.
  """
  @spec list_blocks_of_type(GenServer.server(), atom(), integer()) :: {:ok, list}  | {:error, map}
  def list_blocks_of_type(pid, block_type, n_items) do
    GenServer.call(pid, {:list_blocks_of_type, block_type, n_items})
  end

  @doc """
  Return detail information about an AG given block.
  This function is very useful if you nead to read or write data in a DB
  which you do not know the size in advance (see pg 127).
  """
  @spec get_ag_block_info(GenServer.server(), atom(), integer()) :: {:ok, list}  | {:error, map}
  def get_ag_block_info(pid, block_type, block_num) do
    GenServer.call(pid, {:get_ag_block_info, block_type, block_num})
  end

  @doc """
  Return detailed information about a block present in a user buffer.
  This function is usually used in conjunction with full_upload/2.
  An uploaded a block saved to disk, could be loaded in a user buffer
  and checked with this function.
  """
  @spec get_pg_block_info(GenServer.server(), binary()) :: {:ok, list}  | {:error, map}
  def get_pg_block_info(pid, buffer) do
    GenServer.call(pid, {:get_pg_block_info, buffer})
  end

  def init([]) do
    System.put_env("LD_LIBRARY_PATH", "./src") #change this to :code.priv_dir (Change Makefile)
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

  # Administrative funtions

  def handle_call({:connect_to, opts}, {from_pid, _}, state) do
    ip = Keyword.get(opts, :ip, nil)
    rack = Keyword.get(opts, :rack, 0)
    slot = Keyword.get(opts, :slot,  0)
    active = Keyword.get(opts, :active,  false)

    response = call_port(state, :connect_to, {ip, rack, slot})
    new_state =
      case response do
        :ok ->
            %State{state |
              state: :connected,
              ip: ip,
              rack: rack,
              slot: slot,
              is_active: active,
              controlling_process: from_pid
            }

        {:error, _x} ->
          %State{state | state: :idle}
      end

    {:reply, response, new_state}
  end

  # Directory functions

  def handle_call(:list_blocks, _from, state) do
    response = call_port(state, :list_blocks, nil)
    {:reply, response, state}
  end

  def handle_call({:list_blocks_of_type, block_type, n_items}, _from, state) do
    block_value = Keyword.fetch!(@block_types, block_type)
    response = call_port(state, :list_blocks_of_type, {block_value, n_items})
    {:reply, response, state}
  end

  def handle_call({:get_ag_block_info, block_type, block_num}, _from, state) do
    block_value = Keyword.fetch!(@block_types, block_type)
    response = call_port(state, :get_ag_block_info, {block_value, block_num})
    {:reply, response, state}
  end

  def handle_call({:get_pg_block_info, buffer}, _from, state) do
    b_size = byte_size(buffer)
    response = call_port(state, :get_pg_block_info, {b_size, buffer})
    {:reply, response, state}
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
