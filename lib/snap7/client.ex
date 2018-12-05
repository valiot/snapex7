defmodule Snapex7.Client do
  use GenServer
  require Logger

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

  @area_types [
    PE: 0x81,
    PA: 0x82,
    MK: 0x83,
    DB: 0x84,
    CT: 0x1C,
    TM: 0x1D
  ]

  @word_types [
    bit: 0x01,
    byte: 0x02,
    word: 0x04,
    d_word: 0x06,
    real: 0x08,
    counter: 0x1C,
    timer: 0x1D
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
  @spec start_link([term]) :: {:ok, pid} | {:error, term} | {:error, :einval}
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
          {:ip, bitstring}
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

  @type data_io_opt ::
          {:area, atom}
          | {:db_number, integer}
          | {:start, integer}
          | {:amount, integer}
          | {:word_len, atom}
          | {:data, bitstring}
  # Data I/O functions

  @doc """
  Reads a data area from a PLC.
  The following options are available:

    * `:area` - (atom) Area Identifier (see @area_types).

    * `:db_number` - (int) DB number, if `area: :DB` otherwise is ignored.

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words to read/write.

    * `:word_len` - (atom) Word size (see @word_types).

  For more info see pg. 104 form Snap7 docs.
  """
  @spec read_area(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def read_area(pid, opts) do
    GenServer.call(pid, {:read_area, opts})
  end

  @doc """
  Write a data area from a PLC.
  The following options are available:

    * `:area` - (atom) Area Identifier (see @area_types).

    * `:db_number` - (int) DB number, if `area: :DB` otherwise is ignored.

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words to read/write.

    * `:word_len` - (atom) Word size (see @word_types).

    * `:data` - (atom) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec write_area(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def write_area(pid, opts) do
    GenServer.call(pid, {:write_area, opts})
  end

  @doc """
  This is a lean function of read_area/2 to read PLC DB.
  It simply internally calls read_area/2 with
    * `area: :DB`
    * `word_len: :byte`

  The following options are available:

    * `:db_number` - (int) DB number (0..0xFFFF).

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec db_read(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def db_read(pid, opts) do
    GenServer.call(pid, {:db_read, opts})
  end

  @doc """
  This is a lean function of write_area/2 to write PLC DB.
  It simply internally calls read_area/2 with
    * `area: :DB`
    * `word_len: :byte`

  The following options are available:

    * `:db_number` - (int) DB number (0..0xFFFF).

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

    * `:data` - (bitstring) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec db_write(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def db_write(pid, opts) do
    GenServer.call(pid, {:db_write, opts})
  end

  @doc """
  This is a lean function of read_area/2 to read PLC process outputs.
  It simply internally calls read_area/2 with
    * `area: :PA`
    * `word_len: :byte`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write .

  For more info see pg. 104 form Snap7 docs.
  """
  @spec ab_read(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def ab_read(pid, opts) do
    GenServer.call(pid, {:ab_read, opts})
  end

  @doc """
  This is a lean function of write_area/2 to write PLC process outputs.
  It simply internally calls read_area/2 with
    * `area: :PA`
    * `word_len: :byte`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

    * `:data` - (bitstring) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec ab_write(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def ab_write(pid, opts) do
    GenServer.call(pid, {:ab_write, opts})
  end

  @doc """
  This is a lean function of read_area/2 to read PLC process inputs.
  It simply internally calls read_area/2 with
    * `area: :PE`
    * `word_len: :byte`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write .

  For more info see pg. 104 form Snap7 docs.
  """
  @spec eb_read(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def eb_read(pid, opts) do
    GenServer.call(pid, {:eb_read, opts})
  end

  @doc """
  This is a lean function of write_area/2 to write PLC process inputs.
  It simply internally calls read_area/2 with
    * `area: :PE`
    * `word_len: :byte`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

    * `:data` - (bitstring) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec eb_write(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def eb_write(pid, opts) do
    GenServer.call(pid, {:eb_write, opts})
  end

  @doc """
  This is a lean function of read_area/2 to read PLC merkers.
  It simply internally calls read_area/2 with
    * `area: :MK`
    * `word_len: :byte`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write .

  For more info see pg. 104 form Snap7 docs.
  """
  @spec mb_read(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def mb_read(pid, opts) do
    GenServer.call(pid, {:mb_read, opts})
  end

  @doc """
  This is a lean function of write_area/2 to write PLC merkers.
  It simply internally calls read_area/2 with
    * `area: :MK`
    * `word_len: :byte`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

    * `:data` - (bitstring) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec mb_write(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def mb_write(pid, opts) do
    GenServer.call(pid, {:mb_write, opts})
  end

  @doc """
  This is a lean function of read_area/2 to read PLC Timers.
  It simply internally calls read_area/2 with
    * `area: :TM`
    * `word_len: :timer`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write .

  For more info see pg. 104 form Snap7 docs.
  """
  @spec tm_read(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def tm_read(pid, opts) do
    GenServer.call(pid, {:tm_read, opts})
  end

  @doc """
  This is a lean function of write_area/2 to write PLC Timers.
  It simply internally calls read_area/2 with
    * `area: :TM`
    * `word_len: :timer`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

    * `:data` - (bitstring) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec tm_write(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def tm_write(pid, opts) do
    GenServer.call(pid, {:tm_write, opts})
  end

  @doc """
  This is a lean function of read_area/2 to read PLC Counters.
  It simply internally calls read_area/2 with
    * `area: :CT`
    * `word_len: :timer`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write .

  For more info see pg. 104 form Snap7 docs.
  """
  @spec ct_read(GenServer.server(), [data_io_opt]) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def ct_read(pid, opts) do
    GenServer.call(pid, {:ct_read, opts})
  end

  @doc """
  This is a lean function of write_area/2 to write PLC Counters.
  It simply internally calls read_area/2 with
    * `area: :CT`
    * `word_len: :timer`

  The following options are available:

    * `:start` - (int) An offset to start.

    * `:amount` - (int) Amount of words (bytes) to read/write.

    * `:data` - (bitstring) buffer to write.

  For more info see pg. 104 form Snap7 docs.
  """
  @spec ct_write(GenServer.server(), [data_io_opt]) :: :ok | {:error, map()} | {:error, :einval}
  def ct_write(pid, opts) do
    GenServer.call(pid, {:ct_write, opts})
  end

  @doc """
  This function allows to read different kind of variables from a PLC in a single call.
  With it can read DB, inputs, outputs, Merkers, Timers and Counters.

  The following options are available:

    * `:data` - (list of maps) a list of requests (maps with @data_io_opt options as keys) to read from PLC.

  For more info see pg. 119 form Snap7 docs.
  """
  @spec read_multi_vars(GenServer.server(), list) ::
          {:ok, bitstring} | {:error, map()} | {:error, :einval}
  def read_multi_vars(pid, opt) do
    GenServer.call(pid, {:read_multi_vars, opt})
  end

  @doc """
  This function allows to write different kind of variables from a PLC in a single call.
  With it can read DB, inputs, outputs, Merkers, Timers and Counters.

  The following options are available:

    * `:data` - (list of maps) a list of requests (maps with @data_io_opt options as keys) to read from PLC.

  For more info see pg. 119 form Snap7 docs.
  """
  @spec write_multi_vars(GenServer.server(), [data_io_opt]) ::
          :ok | {:error, map()} | {:error, :einval}
  def write_multi_vars(pid, opts) do
    GenServer.call(pid, {:write_multi_vars, opts})
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
  @spec get_ag_block_info(GenServer.server(), atom(), integer()) ::
          {:ok, list} | {:error, map} | {:error, :einval}
  def get_ag_block_info(pid, block_type, block_num) do
    GenServer.call(pid, {:get_ag_block_info, block_type, block_num})
  end

  @doc """
  Return detailed information about a block present in a user buffer.
  This function is usually used in conjunction with full_upload/2.
  An uploaded a block saved to disk, could be loaded in a user buffer
  and checked with this function.
  """
  @spec get_pg_block_info(GenServer.server(), bitstring()) ::
          {:ok, list} | {:error, map} | {:error, :einval}
  def get_pg_block_info(pid, buffer) do
    GenServer.call(pid, {:get_pg_block_info, buffer})
  end

  # Block Oriented functions

  @doc """
  Uploads a block from AG. (gets a block from PLC)
  The whole block (including header and footer) is copied into the user buffer (as bytes).
  """
  @spec full_upload(GenServer.server(), atom(), integer(), integer()) ::
          {:ok, bitstring} | {:error, map} | {:error, :einval}
  def full_upload(pid, block_type, block_num, bytes2read) do
    GenServer.call(pid, {:full_upload, block_type, block_num, bytes2read})
  end

  @doc """
  Uploads a block from AG. (gets a block from PLC)
  Only the block body (but header and footer) is copied into the user buffer (as bytes).
  """
  @spec upload(GenServer.server(), atom(), integer(), integer()) ::
          {:ok, bitstring} | {:error, map} | {:error, :einval}
  def upload(pid, block_type, block_num, bytes2read) do
    GenServer.call(pid, {:upload, block_type, block_num, bytes2read})
  end

  @doc """
  Downloads a block from AG. (gets a block from PLC)
  The whole block (including header and footer) must be available into the user buffer.
  """
  @spec download(GenServer.server(), integer(), bitstring()) ::
          :ok | {:error, map} | {:error, :einval}
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
  @spec db_get(GenServer.server(), integer(), integer()) ::
          {:ok, list} | {:error, map} | {:error, :einval}
  def db_get(pid, db_number, size \\ 65536) do
    GenServer.call(pid, {:db_get, db_number, size})
  end

  @doc """
  Fills a DB in AG qirh a given byte without the need of specifying its size.
  """
  @spec db_fill(GenServer.server(), integer(), integer()) ::
          {:ok, list} | {:error, map} | {:error, :einval}
  def db_fill(pid, db_number, fill_char) do
    GenServer.call(pid, {:db_fill, db_number, fill_char})
  end

  # Date/Time functions

  @doc """
  Reads PLC date and time, if successful, returns `{:ok, date, time}`
  """
  @spec get_plc_date_time(GenServer.server()) ::
          {:ok, term, term} | {:error, map} | {:error, :einval}
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
  @spec set_plc_date_time(GenServer.server(), [plc_time_opt]) ::
          :ok | {:error, map} | {:error, :einval}
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
  @spec read_szl(GenServer.server(), integer, integer) ::
          {:ok, bitstring} | {:error, map} | {:error, :einval}
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
  @spec set_session_password(GenServer.server(), bitstring()) ::
          :ok | {:error, map} | {:error, :einval}
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
  @spec iso_exchange_buffer(GenServer.server(), bitstring) ::
          :ok | {:error, map} | {:error, :einval}
  def iso_exchange_buffer(pid, buffer) do
    GenServer.call(pid, {:iso_exchange_buffer, buffer})
  end

  # Miscellaneous functions

  @doc """
  Returns the last job execution time in miliseconds.
  """
  @spec get_exec_time(GenServer.server()) :: {:ok, integer} | {:error, map} | {:error, :einval}
  def get_exec_time(pid) do
    GenServer.call(pid, :get_exec_time)
  end

  @doc """
  Returns the last job result.
  """
  @spec get_last_error(GenServer.server()) :: {:ok, map} | {:error, map} | {:error, :einval}
  def get_last_error(pid) do
    GenServer.call(pid, :get_last_error)
  end

  @doc """
  Returns info about the PDU length.
  """
  @spec get_pdu_length(GenServer.server()) :: {:ok, list} | {:error, map} | {:error, :einval}
  def get_pdu_length(pid) do
    GenServer.call(pid, :get_pdu_length)
  end

  @doc """
  Returns the connection status.
  """
  @spec get_connected(GenServer.server()) :: {:ok, boolean} | {:error, map} | {:error, :einval}
  def get_connected(pid) do
    GenServer.call(pid, :get_connected)
  end

  @doc """
  This function can execute any desired function as a request.
  The `request` can be a tuple (the first element is an atom according to the desired function to be executed,
  and the following elements are the args of the desired function) or an atom (when the desired function
  has no arguments), for example:
    request = {:connect_to , [ip: "192.168.1.100", rack: 0, slot: 0]},
    request = :get_connected
  """
  @spec command(GenServer.server(), term) :: :ok | {:ok, term} | {:error, map} | {:error, :einval}
  def command(pid, request) do
    GenServer.call(pid, request)
  end

  @spec init([]) :: {:ok, Snapex7.Client.State.t()}
  def init([]) do
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

    state = %State{port: port}
    {:ok, state}
  end

  # Administrative funtions

  def handle_call({:connect_to, opts}, {from_pid, _}, state) do
    ip = Keyword.fetch!(opts, :ip)
    rack = Keyword.get(opts, :rack, 0)
    slot = Keyword.get(opts, :slot, 0)
    active = Keyword.get(opts, :active, false)

    response = call_port(state, :connect_to, {ip, rack, slot})

    new_state =
      case response do
        :ok ->
          %State{
            state
            | state: :connected,
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

  # Data I/O functions

  def handle_call({:read_area, opts}, _from, state) do
    area_key = Keyword.fetch!(opts, :area)
    word_len_key = Keyword.get(opts, :word_len, :byte)
    db_number = Keyword.get(opts, :db_number, 0)
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    area_type = Keyword.fetch!(@area_types, area_key)
    word_type = Keyword.fetch!(@word_types, word_len_key)
    response = call_port(state, :read_area, {area_type, db_number, start, amount, word_type})
    {:reply, response, state}
  end

  def handle_call({:write_area, opts}, _from, state) do
    area_key = Keyword.fetch!(opts, :area)
    word_len_key = Keyword.get(opts, :word_len, :byte)
    db_number = Keyword.get(opts, :db_number, 0)
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    area_type = Keyword.fetch!(@area_types, area_key)
    word_type = Keyword.fetch!(@word_types, word_len_key)

    response =
      call_port(state, :write_area, {area_type, db_number, start, amount, word_type, data})

    {:reply, response, state}
  end

  def handle_call({:db_read, opts}, _from, state) do
    db_number = Keyword.get(opts, :db_number, 0)
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    response = call_port(state, :db_read, {db_number, start, amount})
    {:reply, response, state}
  end

  def handle_call({:db_write, opts}, _from, state) do
    db_number = Keyword.get(opts, :db_number, 0)
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    response = call_port(state, :db_write, {db_number, start, amount, data})
    {:reply, response, state}
  end

  def handle_call({:ab_read, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    response = call_port(state, :ab_read, {start, amount})
    {:reply, response, state}
  end

  def handle_call({:ab_write, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    response = call_port(state, :ab_write, {start, amount, data})
    {:reply, response, state}
  end

  def handle_call({:eb_read, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    response = call_port(state, :eb_read, {start, amount})
    {:reply, response, state}
  end

  def handle_call({:eb_write, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    response = call_port(state, :eb_write, {start, amount, data})
    {:reply, response, state}
  end

  def handle_call({:mb_read, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    response = call_port(state, :mb_read, {start, amount})
    {:reply, response, state}
  end

  def handle_call({:mb_write, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    response = call_port(state, :mb_write, {start, amount, data})
    {:reply, response, state}
  end

  def handle_call({:tm_read, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    response = call_port(state, :tm_read, {start, amount})
    {:reply, response, state}
  end

  def handle_call({:tm_write, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    response = call_port(state, :tm_write, {start, amount, data})
    {:reply, response, state}
  end

  def handle_call({:ct_read, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    amount = Keyword.get(opts, :amount, 0)
    response = call_port(state, :ct_read, {start, amount})
    {:reply, response, state}
  end

  def handle_call({:ct_write, opts}, _from, state) do
    start = Keyword.get(opts, :start, 0)
    data = Keyword.fetch!(opts, :data)
    amount = Keyword.get(opts, :amount, byte_size(data))
    response = call_port(state, :ct_write, {start, amount, data})
    {:reply, response, state}
  end

  def handle_call({:read_multi_vars, opts}, _from, state) do
    data = Keyword.fetch!(opts, :data) |> Enum.map(&key2value/1)
    size = length(data)
    response = call_port(state, :read_multi_vars, {size, data})
    {:reply, response, state}
  end

  def handle_call({:write_multi_vars, opts}, _from, state) do
    data = Keyword.fetch!(opts, :data) |> Enum.map(&key2value/1)
    size = length(data)
    response = call_port(state, :write_multi_vars, {size, data})
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

  # Date/Time functions

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

    response =
      call_port(state, :set_plc_date_time, {sec, min, hour, mday, mon, year, wday, yday, isdst})

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

  # Security functions

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

  # Miscellaneous functions

  def handle_call(:get_exec_time, _from, state) do
    response = call_port(state, :get_exec_time, nil)
    {:reply, response, state}
  end

  def handle_call(:get_last_error, _from, state) do
    response = call_port(state, :get_last_error, nil)
    {:reply, response, state}
  end

  def handle_call(:get_pdu_length, _from, state) do
    response = call_port(state, :get_pdu_length, nil)
    {:reply, response, state}
  end

  def handle_call(:get_connected, _from, state) do
    response = call_port(state, :get_connected, nil)
    {:reply, response, state}
  end

  def handle_call(request, _from, state) do
    Logger.error("(#{__MODULE__}) Invalid request: #{inspect(request)}")
    response = {:error, :einval}
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

  defp key2value(map) do
    area_key = Map.fetch!(map, :area)
    area_value = Keyword.fetch!(@area_types, area_key)
    map = Map.put(map, :area, area_value)
    word_len_key = Map.get(map, :word_len, :byte)
    word_len_value = Keyword.get(@word_types, word_len_key)
    map = Map.put(map, :word_len, word_len_value)
    map
  end
end
