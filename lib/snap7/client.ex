defmodule Snapex7.Client do
  use GenServer

  @c_timeout 5000

  @block_types [
    OB: 0x38,
    DB: 0x41,
    SDB: 0x42,
    FC: 0x43,
    SFC: 0x44,
    FB: 0x45,
    SFB: 0x46
  ]

  @connection_types [
    PG: 0x01,
    OP: 0x02,
    S7_basic: 0x03
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
  @spec start_link([term]) :: {:ok, pid} | {:error, term} | {:error,:einval}
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
          | {:local_tsap, integer}
          | {:remote_tsap, integer}

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
  @spec connect_to(GenServer.server(), [connect_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def connect_to(pid, opts \\ []) do
    GenServer.call(pid, {:connect_to, opts})
  end

  @doc """
  Sets the connection resource type, i.e the way in which the Clients connects to a PLC.
  """
  @spec set_connection_type(GenServer.server(), atom()) ::
          :ok | {:error, map()} | {:error, :einval}
  def set_connection_type(pid, connection_type) do
    GenServer.call(pid, {:set_connection_type, connection_type})
  end

  @doc """
  Sets internally (IP, LocalTSAP, RemoteTSAP) Coordinates
  The following options are available:

    * `:ip` - (string) PLC/Equipment IPV4 Address (e.g., "192.168.0.1")

    * `:local_tsap` - (int) Local TSAP (PC TSAP) // 0.

    * `:remote_tsap` - (int) Remote TSAP (PLC TSAP) // 0.
  """
  @spec set_connection_params(GenServer.server(), [connect_opt]) ::
          :ok | {:error, map()} | {:error, :einval}
  def set_connection_params(pid, opts \\ []) do
    GenServer.call(pid, {:set_connection_params, opts})
  end

  @doc """
  Connects the client to the PLC with the parameters specified in the previous call of
  `connect_to/2` or `set_connection_params/2`.
  """
  @spec connect(GenServer.server()) :: :ok | {:error, map()} | {:error, :einval}
  def connect(pid) do
    GenServer.call(pid, :connect)
  end

  @doc """
  Disconnects “gracefully” the Client from the PLC.
  """
  @spec disconnect(GenServer.server()) :: :ok | {:error, map()} | {:error, :einval}
  def disconnect(pid) do
    GenServer.call(pid, :disconnect)
  end

  @doc """
  Reads an internal Client object parameter.
  For more info see pg. 89 form Snap7 docs.
  """
  @spec get_params(GenServer.server(), integer()) :: :ok | {:error, map()} | {:error, :einval}
  def get_params(pid, param_number) do
    GenServer.call(pid, {:get_params, param_number})
  end

  @doc """
  Sets an internal Client object parameter.
  """
  @spec set_params(GenServer.server(), integer(), integer()) ::
          :ok | {:error, map()} | {:error, :einval}
  def set_params(pid, param_number, value) do
    GenServer.call(pid, {:set_params, param_number, value})
  end

  # Directory functions

  @doc """
  This function returns the AG blocks amount divided by type.
  """
  @spec list_blocks(GenServer.server()) :: {:ok, list} | {:error, map()} | {:error, :einval}
  def list_blocks(pid) do
    GenServer.call(pid, :list_blocks)
  end

  @doc """
  This function returns the AG list of a specified block type.
  """
  @spec list_blocks_of_type(GenServer.server(), atom(), integer()) ::
          {:ok, list} | {:error, map} | {:error, :einval}
  def list_blocks_of_type(pid, block_type, n_items) do
    GenServer.call(pid, {:list_blocks_of_type, block_type, n_items})
  end

  @doc """
  Return detail information about an AG given block.
  This function is very useful if you nead to read or write data in a DB
  which you do not know the size in advance (see pg 127).
  """
  @spec get_ag_block_info(GenServer.server(), atom(), integer()) :: {:ok, list}  | {:error, map} | {:error, :einval}
  def get_ag_block_info(pid, block_type, block_num) do
    GenServer.call(pid, {:get_ag_block_info, block_type, block_num})
  end

  @doc """
  Return detailed information about a block present in a user buffer.
  This function is usually used in conjunction with full_upload/2.
  An uploaded a block saved to disk, could be loaded in a user buffer
  and checked with this function.
  """
  @spec get_pg_block_info(GenServer.server(), binary()) :: {:ok, list}  | {:error, map} | {:error,:einval}
  def get_pg_block_info(pid, buffer) do
    GenServer.call(pid, {:get_pg_block_info, buffer})
  end

  # Block Oriented functions

  @doc """
  Uploads a block from AG. (gets a block from PLC)
  The whole block (including header and footer) is copied into the user buffer (as bytes).
  """
  @spec full_upload(GenServer.server(), atom(), integer(), integer()) :: {:ok, binary}  | {:error, map} | {:error, :einval}
  def full_upload(pid, block_type, block_num, bytes2read) do
    GenServer.call(pid, {:full_upload, block_type, block_num, bytes2read})
  end

  @doc """
  Uploads a block from AG. (gets a block from PLC)
  Only the block body (but header and footer) is copied into the user buffer (as bytes).
  """
  @spec upload(GenServer.server(), atom(), integer(), integer()) :: {:ok, binary}  | {:error, map} | {:error, :einval}
  def upload(pid, block_type, block_num, bytes2read) do
    GenServer.call(pid, {:upload, block_type, block_num, bytes2read})
  end

  @doc """
  Downloads a block from AG. (gets a block from PLC)
  The whole block (including header and footer) must be available into the user buffer.
  """
  @spec download(GenServer.server(), integer(), binary()) :: :ok | {:error, map} | {:error, :einval}
  def download(pid, block_num, buffer) do
    GenServer.call(pid, {:download, block_num, buffer})
  end

  @doc """
  Deletes a block from AG.
  (There is an undo function available).
  """
  @spec delete(GenServer.server(), atom(), integer()) :: :ok | {:error, map} | {:error, :einval}
  def delete(pid, block_type, block_num) do
    GenServer.call(pid, {:delete, block_type, block_num})
  end

  @doc """
  Uploads a DB from AG.
  This function is equivalent to upload/4 with block_type = :DB but it uses a
  different approach so it's  not subject to the security level set.
  Only data is uploaded.
  """
  @spec db_get(GenServer.server(), integer(), integer()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def db_get(pid, db_number, size \\ 65536) do
    GenServer.call(pid, {:db_get, db_number, size})
  end

  @doc """
  Fills a DB in AG qirh a given byte without the need of specifying its size.
  """
  @spec db_fill(GenServer.server(), integer(), integer()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def db_fill(pid, db_number, fill_char) do
    GenServer.call(pid, {:db_fill, db_number, fill_char})
  end

  #Date/Time functions

  @doc """
  Reads PLC date and time, if successful, returns `{:ok, date, time}`
  """
  @spec get_plc_date_time(GenServer.server()) :: {:ok, term, term} | {:error, map} | {:error, :einval}
  def get_plc_date_time(pid) do
    GenServer.call(pid, :get_plc_date_time)
  end

  @type plc_time_opt ::
          {:sec, 0..59}
          | {:min, 0..7}
          | {:hour, 0..23}
          | {:mday, 1..31}
          | {:mon, 1..12}
          | {:year, integer}
          | {:wday, 0..6}
          | {:yday, 0..365}
          | {:isdst, integer}
  @doc """
  Sets PLC date and time.
  The following options are available:

    * `:sec` - (int) seconds afer the minute (0..59).

    * `:min` - (int) minutes after the hour (0..59).

    * `:hour` - (int) hour since midnight (0..23).

    * `:mday` - (int) day of the month (1..31).

    * `:mon` - (int) month since January (1..12).

    * `:year` - (int) year (1900...).

    * `:wday` - (int) days since Sunday (0..6).

    * `:yday` - (int) days since January 1 (0..365).

    * `:isdst` - (int) Daylight Saving Time flag.

  The default is of all functions are the minimum value.
  """
  @spec set_plc_date_time(GenServer.server(), [plc_time_opt]) :: :ok | {:error, map} | {:error, :einval}
  def set_plc_date_time(pid, opts \\ []) do
    GenServer.call(pid, {:set_plc_date_time, opts})
  end

  @doc """
  Sets the PLC date and time in accord to the PC system Date/Time.
  """
  @spec set_plc_system_date_time(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def set_plc_system_date_time(pid) do
    GenServer.call(pid, :set_plc_system_date_time)
  end

  # System info functions

  @doc """
  Reads a partial list of given ID and INDEX
  See System Software for S7-300/400 System and Standard Functions
  Volume 1 and Volume 2 for ID and INDEX info (chapter 13.3), look for
  TIA Portal Information Systems for DR data type.
  """
  @spec read_szl(GenServer.server(), integer, integer) :: {:ok, binary} | {:error, map} | {:error, :einval}
  def read_szl(pid, id, index) do
    GenServer.call(pid, {:read_szl, id, index})
  end

  @doc """
  Reads the directory of the partial list
  """
  @spec read_szl_list(GenServer.server()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def read_szl_list(pid) do
    GenServer.call(pid, :read_szl_list)
  end

  @doc """
  Gets CPU order code and version info.
  """
  @spec get_order_code(GenServer.server()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def get_order_code(pid) do
    GenServer.call(pid, :get_order_code)
  end

  @doc """
  Gets CPU module name, serial number and other info.
  """
  @spec get_cpu_info(GenServer.server()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def get_cpu_info(pid) do
    GenServer.call(pid, :get_cpu_info)
  end

  @doc """
  Gets CP (communication processor) info.
  """
  @spec get_cp_info(GenServer.server()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def get_cp_info(pid) do
    GenServer.call(pid, :get_cp_info)
  end

  # PLC control functions

  @doc """
  Puts the CPU in RUN mode performing an HOT START.
  """
  @spec plc_hot_start(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def plc_hot_start(pid) do
    GenServer.call(pid, :plc_hot_start)
  end

  @doc """
  Puts the CPU in RUN mode performing an COLD START.
  """
  @spec plc_cold_start(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def plc_cold_start(pid) do
    GenServer.call(pid, :plc_cold_start)
  end

  @doc """
  Puts the CPU in STOP mode.
  """
  @spec plc_stop(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def plc_stop(pid) do
    GenServer.call(pid, :plc_stop)
  end

  @doc """
  Performs the copy ram to rom action. (CPU must be in STOP mode)
  """
  @spec copy_ram_to_rom(GenServer.server(), integer) :: :ok | {:error, map} | {:error, :einval}
  def copy_ram_to_rom(pid, timeout \\ 1000) do
    GenServer.call(pid, {:copy_ram_to_rom, timeout})
  end

  @doc """
  Performas the Memory compress action (not all CPU's supports this function and the CPU must be in STOP mode).
  """
  @spec compress(GenServer.server(), integer) :: :ok | {:error, map} | {:error, :einval}
  def compress(pid, timeout \\ 1000) do
    GenServer.call(pid, {:compress, timeout})
  end

  @doc """
  Returns the CPU status (running/stoppped).
  """
  @spec get_plc_status(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def get_plc_status(pid) do
    GenServer.call(pid, :get_plc_status)
  end

  # Security functions

  @doc """
  Send the password (an 8 chars string) to the PLC to meet its security level.
  """
  @spec set_session_password(GenServer.server(), binary()) :: :ok | {:error, map} | {:error, :einval}
  def set_session_password(pid, password) do
    GenServer.call(pid, {:set_session_password, password})
  end

  @doc """
  Clears the password set for the current session (logout).
  """
  @spec clear_session_password(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def clear_session_password(pid) do
    GenServer.call(pid, :clear_session_password)
  end

  @doc """
  Gets the CPU protection level info.
  """
  @spec get_protection(GenServer.server()) :: :ok | {:error, map} | {:error, :einval}
  def get_protection(pid) do
    GenServer.call(pid, :get_protection)
  end

  # Low level functions

  @doc """
  Exchanges a given S7 PDU (protocol data unit) with the CPU.
  """
  @spec iso_exchange_buffer(GenServer.server(), binary) :: :ok | {:error, map} | {:error, :einval}
  def iso_exchange_buffer(pid, buffer) do
    GenServer.call(pid, {:iso_exchange_buffer, buffer})
  end


  @spec init([]) :: {:ok, Snapex7.Client.State.t()}
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
    ip = Keyword.fetch!(opts, :ip)
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

  def handle_call({:set_connection_type, connection_type}, _from, state) do
    connection_type = Keyword.fetch!(@connection_types, connection_type)
    response = call_port(state, :set_connection_type, connection_type)
    {:reply, response, state}
  end

  def handle_call({:set_connection_params, opts}, _from, state) do
    ip = Keyword.fetch!(opts, :ip)
    local_tsap = Keyword.get(opts, :local_tsap, 0)
    remote_tsap = Keyword.get(opts, :remote_tsap, 0)
    response = call_port(state, :set_connection_params, {ip, local_tsap, remote_tsap})
    {:reply, response, state}
  end

  def handle_call(:connect, _from, state) do
    response = call_port(state, :connect, nil)

    new_state =
      case response do
        :ok ->
          %{state | state: :connected}

        {:error, _x} ->
          %State{state | state: :idle}
      end

    {:reply, response, new_state}
  end

  def handle_call(:disconnect, {_from, _}, state) do
    response = call_port(state, :disconnect, nil)
    new_state = %State{state | state: :idle}
    {:reply, response, new_state}
  end

  def handle_call({:get_params, param_number}, {_from, _}, state) do
    response = call_port(state, :get_params, param_number)
    {:reply, response, state}
  end

  def handle_call({:set_params, param_number, value}, {_from, _}, state) do
    response = call_port(state, :set_params, {param_number, value})
    {:reply, response, state}
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

  # Block Oriented functions

  def handle_call({:full_upload, block_type, block_num, bytes2read}, _from, state) do
    block_value = Keyword.fetch!(@block_types, block_type)
    response = call_port(state, :full_upload, {block_value, block_num, bytes2read})
    {:reply, response, state}
  end

  def handle_call({:upload, block_type, block_num, bytes2read}, _from, state) do
    block_value = Keyword.fetch!(@block_types, block_type)
    response = call_port(state, :upload, {block_value, block_num, bytes2read})
    {:reply, response, state}
  end

  def handle_call({:download, block_num, buffer}, _from, state) do
    b_size = byte_size(buffer)
    response = call_port(state, :download, {block_num, b_size, buffer})
    {:reply, response, state}
  end

  def handle_call({:delete, block_type, block_num}, _from, state) do
    block_value = Keyword.fetch!(@block_types, block_type)
    response = call_port(state, :delete, {block_value, block_num})
    {:reply, response, state}
  end

  def handle_call({:db_get, db_number, size}, _from, state) do
    response = call_port(state, :db_get, {db_number, size})
    {:reply, response, state}
  end

  def handle_call({:db_fill, db_number, fill_char}, _from, state) do
    response = call_port(state, :db_fill, {db_number, fill_char})
    {:reply, response, state}
  end

  #Date/Time functions

  def handle_call(:get_plc_date_time, _from, state) do
    response =
     case call_port(state, :get_plc_date_time, nil) do
      {:ok, tm} ->
        {:ok, time} = Time.new(tm.tm_hour, tm.tm_min, tm.tm_sec)
        {:ok, date} = Date.new(tm.tm_year, tm.tm_mon, tm.tm_mday)
        {:ok, date, time}
      x ->
       x
     end
    {:reply, response, state}
  end

  def handle_call({:set_plc_date_time, opt}, _from, state) do
    sec = Keyword.get(opt, :sec, 0)
    min = Keyword.get(opt, :min, 0)
    hour = Keyword.get(opt, :hour, 1)
    mday = Keyword.get(opt, :mday, 1)
    mon = Keyword.get(opt, :mon, 1)
    year = Keyword.get(opt, :year, 1900)
    wday = Keyword.get(opt, :wday, 0)
    yday = Keyword.get(opt, :yday, 0)
    isdst = Keyword.get(opt, :isdst, 1)

    response = call_port(state, :set_plc_date_time, {sec, min, hour, mday, mon, year, wday, yday, isdst})

    {:reply, response, state}
  end

  def handle_call(:set_plc_system_date_time, _from, state) do
    response = call_port(state, :set_plc_system_date_time, nil)
    {:reply, response, state}
  end

  # System info functions

  def handle_call({:read_szl, id, index}, _from, state) do
    response = call_port(state, :read_szl, {id, index})
    {:reply, response, state}
  end

  def handle_call(:read_szl_list, _from, state) do
    response = call_port(state, :read_szl_list, nil)
    {:reply, response, state}
  end

  def handle_call(:get_order_code, _from, state) do
    response = call_port(state, :get_order_code, nil)
    {:reply, response, state}
  end

  def handle_call(:get_cpu_info, _from, state) do
    response = call_port(state, :get_cpu_info, nil)
    {:reply, response, state}
  end

  def handle_call(:get_cp_info, _from, state) do
    response = call_port(state, :get_cp_info, nil)
    {:reply, response, state}
  end

  # PLC control functions

  def handle_call(:plc_hot_start, _from, state) do
    response = call_port(state, :plc_hot_start, nil)
    {:reply, response, state}
  end

  def handle_call(:plc_cold_start, _from, state) do
    response = call_port(state, :plc_cold_start, nil)
    {:reply, response, state}
  end

  def handle_call(:plc_stop, _from, state) do
    response = call_port(state, :plc_stop, nil)
    {:reply, response, state}
  end

  def handle_call({:copy_ram_to_rom, timeout}, _from, state) do
    response = call_port(state, :copy_ram_to_rom, timeout)
    {:reply, response, state}
  end

  def handle_call({:compress, timeout}, _from, state) do
    response = call_port(state, :compress, timeout)
    {:reply, response, state}
  end

  def handle_call(:get_plc_status, _from, state) do
    response = call_port(state, :get_plc_status, nil)
    {:reply, response, state}
  end

  #Security functions

  def handle_call({:set_session_password, password}, _from, state) do
    response = call_port(state, :set_session_password, password)
    {:reply, response, state}
  end

  def handle_call(:clear_session_password, _from, state) do
    response = call_port(state, :clear_session_password, nil)
    {:reply, response, state}
  end

  def handle_call(:get_protection, _from, state) do
    response = call_port(state, :get_protection, nil)
    {:reply, response, state}
  end

  # Low Level functions

  def handle_call({:iso_exchange_buffer, buffer}, _from, state) do
    b_size = byte_size(buffer)
    response = call_port(state, :iso_exchange_buffer, {b_size, buffer})
    {:reply, response, state}
  end

  defp call_port(state, command, arguments, timeout \\ @c_timeout) do
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
